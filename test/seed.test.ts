import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { DEMO_USER } from '../src/db/seed-users';
import { SERVICE_SEEDS } from '../src/db/seed-services';
import { buildTestApp } from './support/app';
import { TEST_BCRYPT_COST, TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';
import { resetServices } from './support/services';
import { resetUsers } from './support/users';

const root = path.resolve(__dirname, '..');
const { app, db } = buildTestApp();

beforeEach(async () => {
  await resetUsers(db);
  await resetServices(db);
});
afterAll(() => db.close());

/** Runs the real `npm run seed` script against the test database. */
function runSeed(extraEnv: Record<string, string> = {}) {
  return spawnSync('npm', ['run', '--silent', 'seed'], {
    cwd: root,
    encoding: 'utf8',
    timeout: 90_000,
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

const count = async (table: 'users' | 'services') =>
  Number((await db.query<{ n: string }>(`SELECT count(*) AS n FROM ${table}`)).rows[0]?.n);

const login = () =>
  request(app).post('/auth/login').send({ email: DEMO_USER.email, password: DEMO_USER.password });

describe('npm run seed', () => {
  it('creates the demo user and the service catalogue', async () => {
    const result = runSeed();
    expect(result.status, result.stderr).toBe(0);
    expect(await count('users')).toBe(1);
    expect(await count('services')).toBe(SERVICE_SEEDS.length);
    expect((await login()).status).toBe(200);
  });

  it('is idempotent: a second run keeps the same rows and the same ids', async () => {
    expect(runSeed().status).toBe(0);
    const before = (await db.query<{ id: string }>('SELECT id FROM services ORDER BY name')).rows;

    expect(runSeed().status).toBe(0);
    const after = (await db.query<{ id: string }>('SELECT id FROM services ORDER BY name')).rows;

    expect(await count('users')).toBe(1);
    expect(await count('services')).toBe(SERVICE_SEEDS.length);
    expect(after).toEqual(before); // updated in place, never deleted and recreated
    expect((await login()).status).toBe(200);
  });

  it('puts edited or deactivated services back to the catalogue values', async () => {
    expect(runSeed().status).toBe(0);
    await db.query(
      "UPDATE services SET price_cents = 1, is_active = false WHERE name = 'Swedish Massage'",
    );
    expect(runSeed().status).toBe(0);
    const row = (
      await db.query<{ price_cents: number; is_active: boolean }>(
        "SELECT price_cents, is_active FROM services WHERE name = 'Swedish Massage'",
      )
    ).rows[0];
    expect(row).toEqual({ price_cents: 6500, is_active: true });
  });

  it('resets the demo password if it was changed', async () => {
    expect(runSeed().status).toBe(0);
    await db.query("UPDATE users SET password_hash = 'garbage' WHERE email = $1", [
      DEMO_USER.email,
    ]);
    expect(runSeed().status).toBe(0);
    expect((await login()).status).toBe(200);
  });

  describe('in production', () => {
    it('seeds the services but never creates the public demo user', async () => {
      const result = runSeed({ NODE_ENV: 'production', JWT_SECRET: 'x'.repeat(48) });
      expect(result.status, result.stderr).toBe(0);
      expect(await count('services')).toBe(SERVICE_SEEDS.length);
      expect(await count('users')).toBe(0);
      expect(result.stdout).toContain('Skipped the demo user');
    });

    it('creates the demo user only when explicitly allowed', async () => {
      const result = runSeed({
        NODE_ENV: 'production',
        JWT_SECRET: 'x'.repeat(48),
        SEED_ALLOW_PRODUCTION: 'true',
      });
      expect(result.status, result.stderr).toBe(0);
      expect(await count('users')).toBe(1);
    });
  });
});

describe('the seeded catalogue', () => {
  const seeds = [...SERVICE_SEEDS];

  it('has about ten services with unique names', () => {
    expect(seeds).toHaveLength(10);
    expect(new Set(seeds.map((s) => s.name)).size).toBe(seeds.length);
  });

  it('spans 3-4 categories', () => {
    const categories = new Set(seeds.map((s) => s.category));
    expect(categories.size).toBeGreaterThanOrEqual(3);
    expect(categories.size).toBeLessThanOrEqual(4);
  });

  it('uses only the durations 30, 45, 60 and 90 minutes, and uses each of them', () => {
    const durations = new Set(seeds.map((s) => s.durationMinutes));
    expect([...durations].sort((a, b) => a - b)).toEqual([30, 45, 60, 90]);
  });

  it('features some, but not all, services', () => {
    const featured = seeds.filter((s) => s.isFeatured).length;
    expect(featured).toBeGreaterThanOrEqual(3);
    expect(featured).toBeLessThan(seeds.length);
  });

  it('has varied, sensible prices and real descriptions', () => {
    const prices = seeds.map((s) => s.priceCents);
    expect(Math.min(...prices)).toBeGreaterThan(0);
    expect(new Set(prices).size).toBeGreaterThan(5);
    for (const s of seeds) expect(s.description.length, s.name).toBeGreaterThan(40);
  });

  it('points every service at an image that exists', () => {
    for (const s of seeds) {
      const file = path.join(root, 'public/images/services', `${s.image}.jpg`);
      expect(existsSync(file), `${s.name}: missing ${s.image}.jpg`).toBe(true);
    }
  });
});
