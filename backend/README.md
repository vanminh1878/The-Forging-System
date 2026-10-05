# HVP API

Node.js 20 + TypeScript + Express + PostgreSQL 16 (raw `pg`, SQL migrations, Row Level Security).

```bash
npm install
cp .env.example .env
npm run migrate        # applies db/migrations/*.sql (owner connection)
npm run seed           # courses, lesson plans, packages, rank gates, notification templates
npm run seed:demo      # dev only: one account per role + sample learners (password hvp12345)
npm run dev            # http://localhost:4000/health
```

## PostgreSQL roles (without Docker)

The API must connect as a non-owner role, otherwise row level security is bypassed.

```sql
CREATE ROLE hvp_owner LOGIN PASSWORD 'hvp_owner_pw' CREATEDB;
CREATE ROLE hvp_app   LOGIN PASSWORD 'hvp_app_pw' NOSUPERUSER NOBYPASSRLS;
CREATE DATABASE hvp_dev  OWNER hvp_owner;
CREATE DATABASE hvp_test OWNER hvp_owner;
GRANT CONNECT ON DATABASE hvp_dev  TO hvp_app;
GRANT CONNECT ON DATABASE hvp_test TO hvp_app;
```

## Scripts

| Script | Purpose |
|---|---|
| `npm run dev` | API with hot reload |
| `npm run build` / `npm start` | compile / run compiled output |
| `npm run typecheck`, `npm run lint`, `npm run format` | static checks |
| `npm test` | unit tests (no database) |
| `npm run test:integration` | integration tests on the `hvp_test` database |
