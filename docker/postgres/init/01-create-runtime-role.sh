#!/bin/bash
# Runs once, when the PostgreSQL data directory is first initialised.
#
# The API must NOT connect as the table owner or a superuser: row level security
# (tenant isolation) is only enforced for roles that are neither. So we create:
#   - hvp_owner : owns the schema, used by migrations only (POSTGRES_USER)
#   - hvp_app   : runtime role used by the API (no ownership, no BYPASSRLS)
set -euo pipefail

: "${HVP_APP_PASSWORD:?HVP_APP_PASSWORD must be set}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hvp_app') THEN
    CREATE ROLE hvp_app LOGIN PASSWORD '${HVP_APP_PASSWORD}' NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
END
\$\$;
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO hvp_app;
SQL

# Extra database used only by the automated test-suite (see docs/TESTING_GUIDE.md).
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
CREATE DATABASE hvp_test OWNER ${POSTGRES_USER};
GRANT CONNECT ON DATABASE hvp_test TO hvp_app;
SQL
