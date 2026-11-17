import { spawnSync } from 'node:child_process';
import path from 'node:path';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { DEMO_USER } from '../src/db/seed-users';
import { buildTestApp } from './support/app';
import { TEST_BCRYPT_COST, TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';
import { resetUsers } from './support/users';

const root = path.resolve(__dirname, '..');
const { app, db } = buildTestApp();

beforeEach(() => resetUsers(db));
afterAll(() => db.close());

/** Runs the real `npm run seed` script against the test database. */
function runSeed(extraEnv: Record<string, string> = {}) {
  return spawnSync('npm', ['run', '--silent', 'seed'], {
    cwd: root,
    encoding: 'utf8',
    timeout: 60_000,
    env: {
      PATH: process.env.PATH ?? '',
      HOME: process.env.HOME ?? '',
      DATABASE_URL: TEST_DATABASE_URL,
      JWT_SECRET: TEST_JWT_SECRET,
      BCRYPT_COST: TEST_BCRYPT_COST,
      NODE_ENV: 'test',
      ...extraEnv,
    },
  });
}

const countUsers = async () =>
  Number((await db.query<{ n: string }>('SELECT count(*) AS n FROM users')).rows[0]?.n);

describe('npm run seed', () => {
  it('creates the demo user, and the demo credentials can log in', async () => {
    const result = runSeed();
    expect(result.status, result.stderr).toBe(0);
    expect(await countUsers()).toBe(1);

    const res = await request(app)
      .post('/auth/login')
      .send({ email: DEMO_USER.email, password: DEMO_USER.password });
    expect(res.status).toBe(200);
    expect(res.body.data.user.name).toBe(DEMO_USER.name);
  });

  it('is idempotent: running it again keeps one user and a working login', async () => {
    expect(runSeed().status).toBe(0);
    expect(runSeed().status).toBe(0);
    expect(await countUsers()).toBe(1);

    const res = await request(app)
      .post('/auth/login')
      .send({ email: DEMO_USER.email, password: DEMO_USER.password });
    expect(res.status).toBe(200);
  });

  it('resets the demo password if it was changed', async () => {
    expect(runSeed().status).toBe(0);
    await db.query("UPDATE users SET password_hash = 'garbage' WHERE email = $1", [
      DEMO_USER.email,
    ]);
    expect(runSeed().status).toBe(0);
    const res = await request(app)
      .post('/auth/login')
      .send({ email: DEMO_USER.email, password: DEMO_USER.password });
    expect(res.status).toBe(200);
  });

  it('refuses to run when NODE_ENV=production', async () => {
    const result = runSeed({ NODE_ENV: 'production' });
    expect(result.status).toBe(1);
    expect(result.stderr).toContain('Refusing to seed demo data');
    expect(await countUsers()).toBe(0);
  });
});
