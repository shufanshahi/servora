import bcrypt from 'bcrypt';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { loadConfig } from '../src/config';
import { TokenService } from '../src/modules/auth/token.service';
import { buildTestApp } from './support/app';
import { TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';
import { resetUsers, validUser } from './support/users';

const logLines: string[] = [];
const { app, db } = buildTestApp(undefined, { logSink: (line) => logLines.push(line) });
const tokens = new TokenService(
  loadConfig({ DATABASE_URL: TEST_DATABASE_URL, JWT_SECRET: TEST_JWT_SECRET }),
);

beforeEach(async () => {
  logLines.length = 0;
  await resetUsers(db);
});
afterAll(() => db.close());

const register = (body: Record<string, unknown>) => request(app).post('/auth/register').send(body);

describe('POST /auth/register', () => {
  it('creates an account and returns the user plus a signed token (201)', async () => {
    const res = await register(validUser);

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    const { user, accessToken, expiresAt } = res.body.data;
    expect(user).toEqual({
      id: expect.stringMatching(/^[0-9a-f-]{36}$/),
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      createdAt: expect.any(String),
    });
    expect(tokens.verify(accessToken).userId).toBe(user.id);
    expect(new Date(expiresAt).getTime()).toBeGreaterThan(Date.now());
  });

  it('trims the name and lower-cases the email', async () => {
    const res = await register({ ...validUser, name: '  Ada  ', email: '  ADA@Example.COM ' });
    expect(res.status).toBe(201);
    expect(res.body.data.user.name).toBe('Ada');
    expect(res.body.data.user.email).toBe('ada@example.com');
  });

  it('stores only a salted hash, never the password', async () => {
    await register(validUser);
    const row = (await db.query<{ password_hash: string }>('SELECT password_hash FROM users'))
      .rows[0];
    expect(row?.password_hash).not.toBe(validUser.password);
    expect(row?.password_hash).not.toContain(validUser.password);
    expect(row?.password_hash).toMatch(/^\$2[aby]\$/);
    expect(await bcrypt.compare(validUser.password, row?.password_hash ?? '')).toBe(true);
  });

  it('salts: the same password hashes differently for two users', async () => {
    await register(validUser);
    await register({ ...validUser, email: 'grace@example.com' });
    const rows = (await db.query<{ password_hash: string }>('SELECT password_hash FROM users'))
      .rows;
    expect(rows).toHaveLength(2);
    expect(rows[0]?.password_hash).not.toBe(rows[1]?.password_hash);
  });

  it('returns no hash or password in the response and writes none to logs', async () => {
    const out = vi.spyOn(console, 'log').mockImplementation(() => undefined);
    const err = vi.spyOn(console, 'error').mockImplementation(() => undefined);

    const res = await register(validUser);

    const raw = JSON.stringify(res.body);
    expect(raw).not.toMatch(/password|hash|\$2[aby]\$/i);
    expect(raw).not.toContain(validUser.password);

    const row = (await db.query<{ password_hash: string }>('SELECT password_hash FROM users'))
      .rows[0];
    const everything = [
      ...logLines,
      ...out.mock.calls.flat().map(String),
      ...err.mock.calls.flat().map(String),
    ].join('\n');
    expect(everything).not.toContain(validUser.password);
    expect(everything).not.toContain(row?.password_hash ?? 'unreachable');
    out.mockRestore();
    err.mockRestore();
  });

  it('ignores unknown fields such as id or role', async () => {
    const res = await register({
      ...validUser,
      id: '00000000-0000-0000-0000-000000000000',
      role: 'admin',
    });
    expect(res.status).toBe(201);
    expect(res.body.data.user.id).not.toBe('00000000-0000-0000-0000-000000000000');
    expect(res.body.data.user).not.toHaveProperty('role');
  });

  describe('duplicate emails', () => {
    it('rejects an email that differs only by letter case (409 EMAIL_TAKEN)', async () => {
      await register(validUser);
      const res = await register({ ...validUser, name: 'Other', email: 'ADA@EXAMPLE.COM' });

      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('EMAIL_TAKEN');
      const count = await db.query<{ n: string }>('SELECT count(*) AS n FROM users');
      expect(count.rows[0]?.n).toBe('1');
    });

    it('lets exactly one of several simultaneous registrations win', async () => {
      const results = await Promise.all(Array.from({ length: 6 }, () => register(validUser)));
      const statuses = results.map((r) => r.status).sort();
      expect(statuses.filter((s) => s === 201)).toHaveLength(1);
      expect(statuses.filter((s) => s === 409)).toHaveLength(5);
      const count = await db.query<{ n: string }>('SELECT count(*) AS n FROM users');
      expect(count.rows[0]?.n).toBe('1');
    });
  });

  describe('validation (422 VALIDATION_ERROR)', () => {
    const fieldsOf = (res: request.Response): string[] =>
      res.body.error.details.map((d: { field: string }) => d.field);

    it.each([
      ['too short', 'Ab1'],
      ['no digit', 'OnlyLetters'],
      ['no letter', '1234567890'],
      ['longer than 72 bytes', `A1${'x'.repeat(80)}`],
    ])('rejects a weak password: %s', async (_label, password) => {
      const res = await register({ ...validUser, password });
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(fieldsOf(res)).toContain('password');
      const count = await db.query<{ n: string }>('SELECT count(*) AS n FROM users');
      expect(count.rows[0]?.n).toBe('0');
    });

    it('accepts a password of exactly 8 characters with a letter and a digit', async () => {
      expect((await register({ ...validUser, password: 'abcdef1x' })).status).toBe(201);
    });

    it.each(['not-an-email', 'a@b', '@example.com', 'a b@example.com', ''])(
      'rejects a malformed email %j',
      async (email) => {
        const res = await register({ ...validUser, email });
        expect(res.status).toBe(422);
        expect(fieldsOf(res)).toContain('email');
      },
    );

    it('rejects an empty or over-long name', async () => {
      const empty = await register({ ...validUser, name: '   ' });
      expect(empty.status).toBe(422);
      expect(fieldsOf(empty)).toContain('name');
      const long = await register({ ...validUser, name: 'x'.repeat(101) });
      expect(long.status).toBe(422);
      expect(fieldsOf(long)).toContain('name');
    });

    it('reports every missing field at once', async () => {
      const res = await register({});
      expect(res.status).toBe(422);
      expect(fieldsOf(res).sort()).toEqual(['email', 'name', 'password']);
    });
  });
});
