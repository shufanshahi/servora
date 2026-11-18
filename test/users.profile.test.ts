import { readFileSync } from 'node:fs';
import path from 'node:path';
import bcrypt from 'bcrypt';
import { parse } from 'yaml';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { registerUser } from './support/appointments';
import { resetUsers } from './support/users';

const { app, db } = buildTestApp();

let ada: { id: string; token: string };
let bob: { id: string; token: string };

beforeEach(async () => {
  await resetUsers(db);
  ada = await registerUser(app, 'ada@example.com');
  bob = await registerUser(app, 'bob@example.com');
});
afterAll(async () => {
  await resetUsers(db);
  await db.close();
});

const me = (token?: string) => {
  const req = request(app).get('/users/me');
  return token ? req.set('Authorization', `Bearer ${token}`) : req;
};
const patch = (token: string, body: Record<string, unknown>) =>
  request(app).patch('/users/me').set('Authorization', `Bearer ${token}`).send(body);
const changePassword = (token: string, body: Record<string, unknown>) =>
  request(app).post('/users/me/password').set('Authorization', `Bearer ${token}`).send(body);

describe('GET /users/me', () => {
  it('returns only the caller’s own non-sensitive fields', async () => {
    const res = await me(ada.token);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual({
      id: ada.id,
      name: 'Test User',
      email: 'ada@example.com',
      phone: null,
      createdAt: expect.any(String),
    });
  });

  it('never exposes credential fields', async () => {
    const text = JSON.stringify((await me(ada.token)).body);
    expect(text).not.toMatch(/password|hash|\$2[aby]\$/i);
  });

  it('is scoped to the token’s user', async () => {
    expect((await me(bob.token)).body.data.email).toBe('bob@example.com');
  });

  it('requires a token', async () => {
    const res = await me();
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('is 401 when the account no longer exists', async () => {
    await db.query('DELETE FROM users WHERE id = $1', [ada.id]);
    expect((await me(ada.token)).status).toBe(401);
  });
});

describe('PATCH /users/me', () => {
  it('updates name and phone and returns the user', async () => {
    const res = await patch(ada.token, { name: '  Ada King  ', phone: ' +1 555 123 4567 ' });
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: ada.id,
      name: 'Ada King',
      phone: '+1 555 123 4567',
      email: 'ada@example.com',
    });
  });

  it('persists: a later read returns the new values', async () => {
    await patch(ada.token, { name: 'Ada King', phone: '555-123-4567' });
    const res = await me(ada.token);
    expect(res.body.data.name).toBe('Ada King');
    expect(res.body.data.phone).toBe('555-123-4567');
  });

  it('can change just one field, leaving the other alone', async () => {
    await patch(ada.token, { phone: '+44 20 7946 0958' });
    const res = await patch(ada.token, { name: 'Only Name' });
    expect(res.body.data).toMatchObject({ name: 'Only Name', phone: '+44 20 7946 0958' });
  });

  it.each(['(555) 123-4567', '+44 20 7946 0958', '555.123.4567', '0044 20 7946 0958'])(
    'accepts the phone %j',
    async (phone) => {
      const res = await patch(ada.token, { phone });
      expect(res.status).toBe(200);
      expect(res.body.data.phone).toBe(phone);
    },
  );

  it('clears the phone with an empty string or null', async () => {
    await patch(ada.token, { phone: '555-123-4567' });
    expect((await patch(ada.token, { phone: '' })).body.data.phone).toBeNull();
    await patch(ada.token, { phone: '555-123-4567' });
    expect((await patch(ada.token, { phone: null })).body.data.phone).toBeNull();
  });

  it('an empty body changes nothing', async () => {
    const res = await patch(ada.token, {});
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('Test User');
  });

  it('rejects an empty or blank name with 422 and leaves data unchanged', async () => {
    for (const name of ['', '   ']) {
      const res = await patch(ada.token, { name });
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details[0].field).toBe('name');
    }
    expect((await me(ada.token)).body.data.name).toBe('Test User');
  });

  it('rejects a name over 100 characters', async () => {
    expect((await patch(ada.token, { name: 'x'.repeat(101) })).status).toBe(422);
  });

  it.each(['abc', '12', '+++', '555 abc 1234', '1'.repeat(16), '12345', '(5'])(
    'rejects the phone %j',
    async (phone) => {
      const res = await patch(ada.token, { phone });
      expect(res.status).toBe(422);
      expect(res.body.error.details[0].field).toBe('phone');
    },
  );

  it('rejects a phone that is not text', async () => {
    expect((await patch(ada.token, { phone: 5551234567 })).status).toBe(422);
  });

  it('ignores id, email and any other field', async () => {
    const res = await patch(ada.token, {
      name: 'Ada King',
      id: bob.id,
      email: 'hacker@example.com',
      passwordHash: 'x',
      password: 'Changed123',
      createdAt: '2000-01-01T00:00:00Z',
    });
    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(ada.id);
    expect(res.body.data.email).toBe('ada@example.com');
    expect(res.body.data.createdAt).not.toBe('2000-01-01T00:00:00.000Z');
    const { rows } = await db.query<{ email: string }>('SELECT email FROM users ORDER BY email');
    expect(rows.map((r) => r.email)).toEqual(['ada@example.com', 'bob@example.com']);
    // Bob was not touched.
    expect((await me(bob.token)).body.data.name).toBe('Test User');
  });

  it('only ever changes the caller', async () => {
    await patch(ada.token, { name: 'Ada King' });
    expect((await me(bob.token)).body.data.name).toBe('Test User');
  });

  it('requires a token', async () => {
    const res = await request(app).patch('/users/me').send({ name: 'x' });
    expect(res.status).toBe(401);
  });
});

describe('POST /users/me/password', () => {
  it('replaces the password: the new one logs in, the old one does not', async () => {
    const res = await changePassword(ada.token, {
      currentPassword: 'Sup3rSecret',
      newPassword: 'N3wPassword!',
    });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: { changed: true } });

    const login = (password: string) =>
      request(app).post('/auth/login').send({ email: 'ada@example.com', password });
    expect((await login('N3wPassword!')).status).toBe(200);
    expect((await login('Sup3rSecret')).status).toBe(401);
  });

  it('stores a bcrypt hash, never the password', async () => {
    await changePassword(ada.token, {
      currentPassword: 'Sup3rSecret',
      newPassword: 'N3wPassword!',
    });
    const { rows } = await db.query<{ password_hash: string }>(
      'SELECT password_hash FROM users WHERE id = $1',
      [ada.id],
    );
    expect(await bcrypt.compare('N3wPassword!', rows[0]?.password_hash ?? '')).toBe(true);
    expect(rows[0]?.password_hash).not.toContain('N3wPassword!');
  });

  it('a wrong current password is 401 INVALID_CREDENTIALS and changes nothing', async () => {
    const res = await changePassword(ada.token, {
      currentPassword: 'WrongPass1',
      newPassword: 'N3wPassword!',
    });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
    const login = await request(app)
      .post('/auth/login')
      .send({ email: 'ada@example.com', password: 'Sup3rSecret' });
    expect(login.status).toBe(200);
  });

  it.each([
    ['too short', 'Ab1'],
    ['no number', 'OnlyLetters'],
    ['no letter', '12345678'],
  ])('a weak new password (%s) is 422 on newPassword', async (_name, newPassword) => {
    const res = await changePassword(ada.token, { currentPassword: 'Sup3rSecret', newPassword });
    expect(res.status).toBe(422);
    expect(res.body.error.details[0].field).toBe('newPassword');
  });

  it('rejects reusing the current password', async () => {
    const res = await changePassword(ada.token, {
      currentPassword: 'Sup3rSecret',
      newPassword: 'Sup3rSecret',
    });
    expect(res.status).toBe(422);
    expect(res.body.error.details[0].field).toBe('newPassword');
  });

  it('requires both fields', async () => {
    expect((await changePassword(ada.token, { newPassword: 'N3wPassword!' })).status).toBe(422);
    expect((await changePassword(ada.token, { currentPassword: 'Sup3rSecret' })).status).toBe(422);
  });

  it('requires a token', async () => {
    const res = await request(app)
      .post('/users/me/password')
      .send({ currentPassword: 'Sup3rSecret', newPassword: 'N3wPassword!' });
    expect(res.status).toBe(401);
  });
});

describe('OpenAPI examples match real responses', () => {
  const spec = parse(readFileSync(path.resolve(__dirname, '../docs/openapi.yaml'), 'utf8')) as {
    paths: Record<string, Record<string, { responses: Record<string, unknown> }>>;
  };
  const exampleData = (route: string, method: string, status: string) => {
    const response = spec.paths[route]?.[method]?.responses[status] as {
      content: { 'application/json': { example: { data: unknown } } };
    };
    return response.content['application/json'].example.data;
  };

  it('GET and PATCH /users/me have exactly the fields the API returns', async () => {
    const real = (await me(ada.token)).body.data as Record<string, unknown>;
    for (const method of ['get', 'patch']) {
      const documented = exampleData('/users/me', method, '200') as Record<string, unknown>;
      expect(Object.keys(documented).sort()).toEqual(Object.keys(real).sort());
    }
  });

  it('POST /users/me/password returns the documented body', async () => {
    const res = await changePassword(ada.token, {
      currentPassword: 'Sup3rSecret',
      newPassword: 'N3wPassword!',
    });
    expect(res.body.data).toEqual(exampleData('/users/me/password', 'post', '200'));
  });
});
