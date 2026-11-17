import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Express } from 'express';
import type { Db } from '../src/db/pool';
import { buildTestApp } from './support/app';
import { resetUsers, validUser } from './support/users';

const LIMIT = 3;

// Every test gets a brand-new app, and therefore a fresh rate-limit budget.
let app: Express;
let db: Db;

beforeEach(async () => {
  ({ app, db } = buildTestApp(undefined, {
    env: { AUTH_RATE_LIMIT_MAX: String(LIMIT), AUTH_RATE_LIMIT_WINDOW_SECONDS: '2' },
  }));
  await resetUsers(db);
});
afterEach(() => db.close());

const badLogin = () =>
  request(app).post('/auth/login').send({ email: 'nobody@example.com', password: 'WrongPass1' });

describe('auth rate limiting', () => {
  it('answers 429 RATE_LIMITED once the attempt limit is exceeded', async () => {
    for (let i = 0; i < LIMIT; i++) {
      expect((await badLogin()).status).toBe(401);
    }
    const res = await badLogin();
    expect(res.status).toBe(429);
    expect(res.body).toEqual({
      success: false,
      error: { code: 'RATE_LIMITED', message: expect.any(String) },
    });
    // Standard rate-limit headers tell clients when to retry.
    expect(res.headers['retry-after']).toBeDefined();
  });

  it('shares one budget between register and login', async () => {
    const register = () =>
      request(app)
        .post('/auth/register')
        .send({ ...validUser, email: `u${Math.random()}@example.com` });
    expect((await register()).status).toBe(201);
    expect((await register()).status).toBe(201);
    expect((await badLogin()).status).toBe(401);
    // Three attempts used (2 registrations + 1 login): the next one is refused.
    expect((await badLogin()).status).toBe(429);
    expect((await register()).status).toBe(429);
  });

  it('also counts requests that fail validation', async () => {
    for (let i = 0; i < LIMIT; i++) {
      expect((await request(app).post('/auth/login').send({})).status).toBe(422);
    }
    expect((await request(app).post('/auth/login').send({})).status).toBe(429);
  });

  it('cannot be bypassed by spoofing X-Forwarded-For', async () => {
    for (let i = 0; i < LIMIT; i++) {
      await badLogin().set('X-Forwarded-For', `10.0.0.${i}`);
    }
    const res = await badLogin().set('X-Forwarded-For', '203.0.113.99');
    expect(res.status).toBe(429);
  });

  it('does not limit other endpoints', async () => {
    for (let i = 0; i < LIMIT + 2; i++) await badLogin();
    expect((await request(app).get('/health')).status).toBe(200);
  });

  it('allows requests again after the window resets', async () => {
    for (let i = 0; i < LIMIT; i++) await badLogin();
    expect((await badLogin()).status).toBe(429);
    await new Promise((resolve) => setTimeout(resolve, 2200));
    expect((await badLogin()).status).toBe(401);
  }, 15_000);
});
