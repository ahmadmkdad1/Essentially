import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import type { DataSourceOptions } from 'typeorm';
import { AuditLog } from '../admin/audit-log.entity.js';
import { Category } from '../categories/category.entity.js';
import { Listing } from '../listings/listing.entity.js';
import { Report } from '../reports/report.entity.js';
import { ServiceRequest } from '../requests/service-request.entity.js';
import { Review } from '../reviews/review.entity.js';
import { User } from '../users/user.entity.js';

export const ENTITIES = [
  User,
  Category,
  Listing,
  ServiceRequest,
  Review,
  Report,
  AuditLog,
];

type Env = (key: string) => string | undefined;

/**
 * Builds TypeORM options from environment variables. PostgreSQL is the
 * primary target; SQLite is supported for zero-setup local runs and tests.
 */
export function buildDatabaseOptions(env: Env): DataSourceOptions {
  const synchronize = (env('DB_SYNCHRONIZE') ?? 'true') === 'true';
  const logging = env('DB_LOGGING') === 'true';

  if (env('DB_TYPE') === 'sqlite') {
    const database = env('DB_SQLITE_PATH') ?? 'data/essentially.sqlite';
    if (database !== ':memory:')
      mkdirSync(dirname(database), { recursive: true });
    return {
      type: 'better-sqlite3',
      database,
      entities: ENTITIES,
      synchronize,
      logging,
    };
  }

  return {
    type: 'postgres',
    host: env('DB_HOST') ?? 'localhost',
    port: Number(env('DB_PORT') ?? 5432),
    username: env('DB_USERNAME') ?? 'postgres',
    password: env('DB_PASSWORD') ?? '',
    database: env('DB_NAME') ?? 'essentially',
    entities: ENTITIES,
    synchronize,
    logging,
  };
}
