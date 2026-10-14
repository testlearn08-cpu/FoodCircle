#!/usr/bin/env bash
#
# Applies the auth stub, then every migration in order, then the behavioural RLS suite —
# all against $DATABASE_URL.
#
#   DATABASE_URL=postgres://user:pass@host:5432/db supabase/tests/run.sh
#
# CI runs exactly this against a `postgres:17` service container (.github/workflows/ci.yml,
# job `db-behaviour`). It needs nothing but a reachable PostgreSQL 14+ and psql.
#
# Unlike test/privacy_test.dart, which greps the migration text, this proves what the policies
# actually do when a client with an anon key or a user JWT talks to the database.

set -euo pipefail

cd "$(dirname "$0")/../.."

: "${DATABASE_URL:=postgres://postgres:postgres@localhost:5432/postgres}"
export PGCONNECT_TIMEOUT=10

psql_run() {
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 --no-psqlrc "$@"
}

echo "== server =="
psql_run -tAc 'select version()'

echo "== auth stub (test infrastructure only) =="
psql_run -q -f supabase/tests/00_auth_stub.sql

echo "== migrations =="
for migration in supabase/migrations/*.sql; do
  echo "   applying $migration"
  psql_run -q -f "$migration"
done

echo "== behavioural RLS suite =="
psql_run -f supabase/tests/10_rls_behaviour.sql

echo
echo "All behavioural RLS tests passed."
