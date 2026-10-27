# Essentially API

NestJS REST API for the Essentially home-services marketplace. See the [root README](../README.md) for the full project overview.

## Run

```bash
npm install
cp .env.example .env     # configure the database + JWT secret
npm run seed             # build, create schema, add demo data (idempotent)
npm run start:dev
```

- API: `http://localhost:3000/api`
- Swagger UI: `http://localhost:3000/docs`
- Health: `GET /api/health`

`npm run seed:fresh` wipes all non-admin data and reseeds (refuses to run with `NODE_ENV=production`).

## Configuration

| Variable | Default | Notes |
|---|---|---|
| `DB_TYPE` | `postgres` | `postgres` or `sqlite` |
| `DB_HOST` / `DB_PORT` / `DB_USERNAME` / `DB_PASSWORD` / `DB_NAME` | `localhost` / `5432` / `postgres` / – / `essentially` | PostgreSQL connection |
| `DB_SQLITE_PATH` | `data/essentially.sqlite` | Used when `DB_TYPE=sqlite` |
| `DB_SYNCHRONIZE` | `true` | Auto-sync schema; disable in production in favour of migrations |
| `JWT_SECRET` | – (required) | At least 16 characters |
| `JWT_EXPIRES_IN` | `7d` | |
| `CORS_ORIGINS` | `*` | Comma-separated list in production |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME` | `admin@essentially.app` / – / `Admin Team` | Admin account created on first start when `ADMIN_PASSWORD` is set (min. 8 characters) |

Create the PostgreSQL database once with `createdb -U postgres essentially` (or via pgAdmin).

## Scripts

| Script | Description |
|---|---|
| `npm run start:dev` | Watch mode |
| `npm run build` / `npm run start:prod` | Production build / run |
| `npm test` | Unit tests (Vitest) |
| `npm run test:e2e` | End-to-end tests against an in-memory database |
| `npm run lint` | oxlint |
| `npm run seed` / `npm run seed:fresh` | Demo data |

## Modules

| Module | Responsibility |
|---|---|
| `auth` | Registration (customer/provider), login, JWT strategy that re-validates account status on each request |
| `users` | Profile, location, password; suspension expiry |
| `categories` | Service categories (seeded) |
| `listings` | Provider services (`/services`), nearby search with distance, soft delete |
| `requests` | Request lifecycle state machine, provider statistics |
| `reviews` | One review per completed request, cached listing ratings |
| `providers` | Public provider profile |
| `reports` | Violation reports on users, services or reviews |
| `admin` | Stats, report resolution, user/service moderation, audit log |
| `health` | Liveness + database check |
