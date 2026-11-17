import type { Express } from 'express';
import { loadConfig } from '../../src/config';
import { createApp, type AppDeps } from '../../src/http/app';
import { createTestDb } from './db';
import { TEST_DATABASE_URL } from './env';

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
    CORS_ORIGINS: 'http://allowed.test',
    ...env,
  });
  const app = createApp({ config, db, ...(extraRoutes ? { extraRoutes } : {}), ...deps });
  return { app, db };
}
