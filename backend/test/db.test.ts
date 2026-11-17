import { spawn } from 'node:child_process';
import path from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';
import { createTestDb } from './support/db';
import { TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';

const db = createTestDb();
afterAll(() => db.close());

describe('database pool', () => {
  it('runs SELECT 1 against the test database', async () => {
    const result = await db.query<{ one: number }>('SELECT 1 AS one');
    expect(result.rows[0]?.one).toBe(1);
  });

  it('has the required extensions installed by migrations', async () => {
    const result = await db.query<{ extname: string }>(
      "SELECT extname FROM pg_extension WHERE extname IN ('citext', 'btree_gist') ORDER BY 1",
    );
    expect(result.rows.map((row) => row.extname)).toEqual(['btree_gist', 'citext']);
  });
});

describe('server process', () => {
  it('exits cleanly (code 0) on SIGINT', async () => {
    const root = path.resolve(__dirname, '..');
    const port = String(41000 + Math.floor(Math.random() * 1000));
    const child = spawn(process.execPath, ['--import', 'tsx', 'src/server.ts'], {
      cwd: root,
      env: {
        ...process.env,
        DATABASE_URL: TEST_DATABASE_URL,
        JWT_SECRET: TEST_JWT_SECRET,
        PORT: port,
        NODE_ENV: 'test',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let output = '';
    child.stdout.on('data', (chunk) => (output += chunk));
    child.stderr.on('data', (chunk) => (output += chunk));

    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`server did not start:\n${output}`)), 15_000);
      const poll = setInterval(() => {
        if (output.includes('listening')) {
          clearTimeout(timer);
          clearInterval(poll);
          resolve();
        }
      }, 100);
    });

    const exit = new Promise<number | null>((resolve) => child.on('exit', (code) => resolve(code)));
    child.kill('SIGINT');
    const code = await Promise.race([
      exit,
      new Promise<'timeout'>((resolve) => setTimeout(() => resolve('timeout'), 10_000)),
    ]);

    expect(code).toBe(0);
    expect(output).toContain('shutting down');
  }, 40_000);
});
