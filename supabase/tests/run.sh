#!/usr/bin/env bash
#
# Applies migrations and runs every database test — all against $DATABASE_URL.
#
#   DATABASE_URL=postgres://user:pass@host:5432/db supabase/tests/run.sh
#
# CI runs exactly this against a `postgres:17` service container (.github/workflows/ci.yml,
# job `db-behaviour`). It needs nothing but a reachable PostgreSQL 14+ and psql.
#
# Two phases, because they answer different questions:
#
#   1. UPGRADE — apply the migrations as they stood before the newest ones, seed rows in the
#                old shape, then apply the newest ones and assert nothing was lost. A migration
#                that only works against an empty database has never really been tested.
#   2. FRESH   — drop everything, apply every migration from empty, then exercise the policies
#                as the roles a real client gets.
#
# Unlike test/privacy_test.dart, which greps the migration text, this proves what the policies
# actually do when a client with an anon key or a user JWT talks to the database.

set -euo pipefail

cd "$(dirname "$0")/../.."

: "${DATABASE_URL:=postgres://postgres:postgres@localhost:5432/postgres}"
export PGCONNECT_TIMEOUT=10

# The migrations that existed before the upgrade path was introduced. Everything from here on is
# applied twice: once on top of seeded legacy rows, once on an empty database.
LEGACY_MIGRATION_COUNT=3

psql_run() {
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 "$@"
}

apply() { # apply <file>
  echo "   applying $1"
  psql_run -q -f "$1"
}

all_migrations=(supabase/migrations/*.sql)
legacy_migrations=("${all_migrations[@]:0:$LEGACY_MIGRATION_COUNT}")
newer_migrations=("${all_migrations[@]:$LEGACY_MIGRATION_COUNT}")

if [ "${#newer_migrations[@]}" -eq 0 ]; then
  echo "no migrations newer than the first $LEGACY_MIGRATION_COUNT: skipping the upgrade phase"
fi

echo "== server =="
psql_run -tAc 'select version()'

# ---------------------------------------------------------------------------------------------
# Phase 1: upgrade an existing, populated database
# ---------------------------------------------------------------------------------------------

echo
echo "== phase 1: upgrade path =="
if [ "${#newer_migrations[@]}" -gt 0 ]; then
  echo "  a database that already ran the first $LEGACY_MIGRATION_COUNT migrations"
  apply supabase/tests/00_auth_stub.sql
  for migration in "${legacy_migrations[@]}"; do apply "$migration"; done

  apply supabase/tests/05_legacy_seed.sql

  echo "  the newer migrations, applied on top"
  for migration in "${newer_migrations[@]}"; do apply "$migration"; done

  psql_run -f supabase/tests/20_migration_upgrade.sql
fi

# ---------------------------------------------------------------------------------------------
# Phase 2: a fresh database, then the behavioural suite
# ---------------------------------------------------------------------------------------------

echo
echo "== phase 2: fresh database =="
psql_run -q -c 'drop schema if exists public cascade; create schema public;'
psql_run -q -c 'drop schema if exists auth cascade;'

apply supabase/tests/00_auth_stub.sql
for migration in "${all_migrations[@]}"; do apply "$migration"; done

echo
echo "== behavioural RLS suite =="
psql_run -f supabase/tests/10_rls_behaviour.sql

echo
echo "All database tests passed."
