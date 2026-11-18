import bcrypt from 'bcrypt';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { loadConfig } from '../src/config';
import { TokenService } from '../src/modules/auth/token.service';
import { buildTestApp } from './support/app';
import { TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';
import { resetUsers, validUser } from './support/users';

const { app, db } = buildTestApp();
const tokens = new TokenService(
  loadConfig({ DATABASE_URL: TEST_DATABASE_URL, JWT_SECRET: TEST_JWT_SECRET }),
);

beforeAll(async () => {
  await resetUsers(db);
  await request(app).post('/auth/register').send(validUser).expect(201);
});
beforeEach(() => vi.restoreAllMocks());
afterAll(async () => {
  await resetUsers(db);
  await db.close();
});

const login = (body: Record<string, unknown>) => request(app).post('/auth/login').send(body);

describe('POST /auth/login', () => {
  it('returns the user and a signed, expiring token on success (200)', async () => {
    const res = await login({ email: validUser.email, password: validUser.password });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const { user, accessToken, expiresAt } = res.body.data;
    expect(user.email).toBe(validUser.email);
    expect(user.name).toBe(validUser.name);
    expect(tokens.verify(accessToken).userId).toBe(user.id);
    const secondsLeft = (new Date(expiresAt).getTime() - Date.now()) / 1000;
    expect(secondsLeft).toBeGreaterThan(7 * 24 * 3600 - 60);
    expect(secondsLeft).toBeLessThanOrEqual(7 * 24 * 3600);
  });

  it('matches the email case-insensitively and ignores surrounding spaces', async () => {
    const res = await login({ email: '  ADA@Example.COM ', password: validUser.password });
    expect(res.status).toBe(200);
  });

  it('never returns a password or hash', async () => {
    const res = await login({ email: validUser.email, password: validUser.password });
    expect(JSON.stringify(res.body)).not.toMatch(/password|hash|\$2[aby]\$/i);
  });

  describe('failures are non-revealing', () => {
    it('gives the identical response for a wrong password and an unknown email', async () => {
      const wrongPassword = await login({ email: validUser.email, password: 'WrongPass1' });
      const unknownEmail = await login({ email: 'nobody@example.com', password: 'WrongPass1' });

      expect(wrongPassword.status).toBe(401);
      expect(unknownEmail.status).toBe(401);
      expect(wrongPassword.body.error.code).toBe('INVALID_CREDENTIALS');
      expect(unknownEmail.body.error.code).toBe('INVALID_CREDENTIALS');
      expect(wrongPassword.body).toEqual(unknownEmail.body);
      expect(wrongPassword.body.error.message).toBe('Incorrect email or password');
    });

    it('treats the password as case-sensitive', async () => {
      const res = await login({
        email: validUser.email,
        password: validUser.password.toLowerCase(),
      });
      expect(res.status).toBe(401);
    });

    it('runs exactly one bcrypt comparison whether or not the email exists', async () => {
      const compare = vi.spyOn(bcrypt, 'compare');

      await login({ email: validUser.email, password: 'WrongPass1' });
      expect(compare).toHaveBeenCalledTimes(1);

      compare.mockClear();
      await login({ email: 'nobody@example.com', password: 'WrongPass1' });
      expect(compare).toHaveBeenCalledTimes(1);
    });

    it('does not reveal strength rules: a weak password is just a 401', async () => {
      const res = await login({ email: validUser.email, password: 'a' });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
    });
  });

  describe('validation (422)', () => {
    it('rejects missing fields', async () => {
      const res = await login({});
      expect(res.status).toBe(422);
      const fields = res.body.error.details.map((d: { field: string }) => d.field).sort();
      expect(fields).toEqual(['email', 'password']);
    });

    it('rejects empty strings and wrong types', async () => {
      expect((await login({ email: '', password: '' })).status).toBe(422);
      expect((await login({ email: 123, password: ['x'] })).status).toBe(422);
    });
  });
});
