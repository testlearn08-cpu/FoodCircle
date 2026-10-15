// Run the database suite from a machine that has no PostgreSQL and no psql.
//
//   npm install --no-save @electric-sql/pglite    # in a scratch directory
//   node tool/run_sql_suite.mjs [--statements]
//
// Why this exists
// ---------------
// The environment this repository is developed from cannot install PostgreSQL, and the CI job
// that *can* run it (`db-behaviour`) takes minutes and — on pull-request runs — publishes no
// logs at all, so a failure there is unreadable from the sandbox. PGlite is PostgreSQL compiled
// to WebAssembly and published on npm, which makes a real database available locally: same
// migrations, same behavioural suite, same answers, seconds per run.
//
// This is a development aid, not a gate, and it is deliberately not wired into CI — CI has a
// real `postgres:17` service container, which is strictly better. Use this to find out whether
// the SQL is right *before* pushing, which is what it is for: it caught two real mistakes in
// migration 006's first version (a bare `%` in a RAISE notice, where it is a format placeholder,
// and two expectations that were simply wrong about the fixture data).
//
//   --statements  send one statement at a time, which is what psql does and therefore what CI
//                 does. Without it, each file goes as a single query, the way a naive client
//                 would. The suite is written to give the same answer either way, so running
//                 both is the check.

import { PGlite } from '@electric-sql/pglite';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// Kept in step with supabase/tests/run.sh: the migrations that existed before the upgrade path
// was introduced. Everything from here on is applied twice — once over seeded legacy rows, once
// on an empty database.
const LEGACY_MIGRATION_COUNT = 3;

const perStatement = process.argv.includes('--statements');

/** Split SQL into statements, respecting strings, dollar-quoted bodies and comments. */
function splitStatements(sql) {
  const out = [];
  let buf = '';
  let i = 0;
  const n = sql.length;

  while (i < n) {
    const c = sql[i];

    if (c === '-' && sql[i + 1] === '-') {
      const end = sql.indexOf('\n', i);
      buf += sql.slice(i, end === -1 ? n : end);
      i = end === -1 ? n : end;
      continue;
    }

    if (c === '/' && sql[i + 1] === '*') {
      let depth = 1;
      let j = i + 2;
      while (j < n && depth > 0) {
        if (sql[j] === '/' && sql[j + 1] === '*') {
          depth++;
          j += 2;
        } else if (sql[j] === '*' && sql[j + 1] === '/') {
          depth--;
          j += 2;
        } else {
          j++;
        }
      }
      buf += sql.slice(i, j);
      i = j;
      continue;
    }

    if (c === "'") {
      let j = i + 1;
      while (j < n) {
        if (sql[j] === "'") {
          if (sql[j + 1] === "'") {
            j += 2;
            continue;
          }
          j++;
          break;
        }
        j++;
      }
      buf += sql.slice(i, j);
      i = j;
      continue;
    }

    if (c === '$') {
      const tag = /^\$[A-Za-z_]*\$/.exec(sql.slice(i));
      if (tag) {
        const end = sql.indexOf(tag[0], i + tag[0].length);
        const j = end === -1 ? n : end + tag[0].length;
        buf += sql.slice(i, j);
        i = j;
        continue;
      }
    }

    if (c === ';') {
      out.push(buf.trim());
      buf = '';
      i++;
      continue;
    }

    buf += c;
    i++;
  }

  if (buf.trim()) out.push(buf.trim());
  return out.filter((s) => s.length > 0);
}

const notices = [];
const failures = [];

async function main() {
  const db = new PGlite();
  await db.waitReady;

  const version = await db.query('select version()');
  console.log(`== server ==\n${version.rows[0].version.split(' on ')[0]}`);
  console.log(`mode: ${perStatement ? 'statement by statement (what psql does, so what CI does)' : 'one query per file'}`);

  const run = async (rel) => {
    const sql = readFileSync(join(ROOT, rel), 'utf8');
    try {
      if (perStatement) {
        for (const statement of splitStatements(sql)) {
          await db.exec(statement, { onNotice: (n) => notices.push(n.message) });
        }
      } else {
        await db.exec(sql, { onNotice: (n) => notices.push(n.message) });
      }
      console.log(`   ok   ${rel}`);
      return true;
    } catch (error) {
      console.log(`   FAIL ${rel}`);
      console.log(`        ${String(error.message).split('\n')[0]}`);
      failures.push(rel);
      return false;
    }
  };

  const all = readdirSync(join(ROOT, 'supabase/migrations'))
    .filter((f) => f.endsWith('.sql'))
    .sort();

  console.log('\n== phase 1: upgrade path ==');
  await run('supabase/tests/00_auth_stub.sql');
  for (const m of all.slice(0, LEGACY_MIGRATION_COUNT)) {
    await run(`supabase/migrations/${m}`);
  }
  await run('supabase/tests/05_legacy_seed.sql');
  for (const m of all.slice(LEGACY_MIGRATION_COUNT)) {
    await run(`supabase/migrations/${m}`);
  }
  await run('supabase/tests/20_migration_upgrade.sql');

  console.log('\n== phase 2: fresh database ==');
  await db.exec('drop schema if exists public cascade; create schema public;');
  await db.exec('drop schema if exists auth cascade;');
  await run('supabase/tests/00_auth_stub.sql');
  for (const m of all) await run(`supabase/migrations/${m}`);

  console.log('\n== behavioural suite ==');
  notices.length = 0;
  const suitePassed = await run('supabase/tests/10_rls_behaviour.sql');

  if (notices.length) {
    console.log(`\n-- ${notices.length} NOTICE(s) from the suite --`);
    for (const message of notices) console.log(`   ${message}`);
  }

  await db.close();

  const ok = failures.length === 0 && suitePassed;
  console.log(ok ? '\nAll database tests passed.' : `\nFAILED (${failures.length} file(s))`);
  process.exit(ok ? 0 : 1);
}

main().catch((error) => {
  console.error('harness error:', error);
  process.exit(2);
});
