#!/bin/sh
# Container start-up: apply migrations, seed reference data (idempotent), optionally demo data, then run the API.
set -e

echo "[entrypoint] running migrations"
npx tsx scripts/migrate.ts

echo "[entrypoint] seeding reference data"
npx tsx scripts/seed.ts

if [ "${SEED_DEMO:-false}" = "true" ]; then
  echo "[entrypoint] seeding demo data"
  npx tsx scripts/seed-demo.ts
fi

exec "$@"
