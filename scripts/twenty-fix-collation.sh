#!/usr/bin/env bash
# Fix PostgreSQL collation version warnings in Twenty CRM's docker container.
# Run on evo-x2: bash scripts/twenty-fix-collation.sh
#
# The warning looks like:
#   WARNING: database "postgres" has a collation version mismatch
#   DETAIL: The database was created using collation version X.Y but
#           the operating system provides version Z.W.
#   HINT: Rebuild all objects in this database that use the default collation
#          and run ALTER DATABASE <db> REFRESH COLLATION VERSION.

set -euo pipefail

CONTAINER="twenty-db-1"
USER="postgres"

echo "==> Checking container '$CONTAINER' is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Container '$CONTAINER' is not running."
  echo "Available containers:"
  docker ps --format '{{.Names}}'
  exit 1
fi

echo "==> Listing databases..."
dbs=$(docker exec "$CONTAINER" psql -U "$USER" -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

for db in $dbs; do
  echo "==> Refreshing collation version for database: $db"
  docker exec "$CONTAINER" psql -U "$USER" -d "$db" -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;"
done

echo ""
echo "==> Verifying — checking for remaining collation warnings..."
warnings=$(docker exec "$CONTAINER" psql -U "$USER" -d postgres -c "
  SELECT datname, datcollversion
  FROM pg_database
  WHERE datistemplate = false
  ORDER BY datname;
")
echo "$warnings"

echo ""
echo "==> Done. Collation versions refreshed."
echo "    If warnings persist after container recreation, re-run this script."
