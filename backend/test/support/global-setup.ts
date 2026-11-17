import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { Client } from 'pg';
import { TEST_DATABASE_URL } from './env';

/** Creates the test database if needed and applies every migration to it. */
export default async function setup(): Promise<void> {
  const url = new URL(TEST_DATABASE_URL);
  const dbName = url.pathname.slice(1);
  if (!/^[a-z0-9_]+$/i.test(dbName) || !dbName.toLowerCase().includes('test')) {
    throw new Error(`Refusing to run tests against database "${dbName}": name must contain "test"`);
  }

  const admin = new Client({
    connectionString: TEST_DATABASE_URL.replace(`/${dbName}`, '/postgres'),
  });
  await admin.connect();
  try {
    const exists = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [dbName]);
    if (exists.rowCount === 0) {
      await admin.query(`CREATE DATABASE "${dbName}"`);
    }
  } finally {
    await admin.end();
  }

  const root = path.resolve(__dirname, '../..');
  execFileSync(
    process.execPath,
    [
      path.join(root, 'node_modules/node-pg-migrate/bin/node-pg-migrate.js'),
      'up',
      '-m',
      path.join(root, 'src/db/migrations'),
      '-j',
      'sql',
    ],
    { cwd: root, env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL }, stdio: 'pipe' },
  );
}
