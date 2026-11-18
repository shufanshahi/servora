import type { Express } from 'express';
import { loadConfig } from '../../src/config';
import { createApp, type AppDeps } from '../../src/http/app';
import { createTestDb } from './db';
import { TEST_BCRYPT_COST, TEST_DATABASE_URL, TEST_JWT_SECRET } from './env';

/** Builds the app against the test database, optionally with extra test-only routes. */
export function buildTestApp(
  extraRoutes?: (app: Express) => void,
  overrides: Partial<AppDeps> & { env?: Record<string, string> } = {},
) {
  const db = createTestDb();
  const { env, ...deps } = overrides;
  const config = loadConfig({
    DATABASE_URL: TEST_DATABASE_URL,
    NODE_ENV: 'test',
    JWT_SECRET: TEST_JWT_SECRET,
    BCRYPT_COST: TEST_BCRYPT_COST,
    // Generous so ordinary tests never trip the limiter; rate-limit tests override it.
    AUTH_RATE_LIMIT_MAX: '1000',
    CORS_ORIGINS: 'http://allowed.test',
    ...env,
  });
  const app = createApp({ config, db, ...(extraRoutes ? { extraRoutes } : {}), ...deps });
  return { app, db };
}
