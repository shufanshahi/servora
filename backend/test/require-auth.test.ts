import jwt from 'jsonwebtoken';
import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config';
import { createRequireAuth, getAuth } from '../src/http/middleware/require-auth';
import { ok } from '../src/http/response';
import { TokenService } from '../src/modules/auth/token.service';
import { buildTestApp } from './support/app';
import { TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';

const config = loadConfig({ DATABASE_URL: TEST_DATABASE_URL, JWT_SECRET: TEST_JWT_SECRET });
const tokens = new TokenService(config);
const requireAuth = createRequireAuth(tokens);

const { app, db } = buildTestApp((a) => {
  a.get('/t/me', requireAuth, (req, res) => {
    ok(res, { userId: getAuth(req).userId });
  });
  // Mounted WITHOUT requireAuth: getAuth must refuse rather than return undefined.
  a.get('/t/unprotected', (req, res) => {
    ok(res, { userId: getAuth(req).userId });
  });
});
afterAll(() => db.close());

const USER_ID = '11111111-2222-3333-4444-555555555555';
const get = (authorization?: string) => {
  const req = request(app).get('/t/me');
  return authorization === undefined ? req : req.set('Authorization', authorization);
};

function expectUnauthenticated(res: request.Response) {
  expect(res.status).toBe(401);
  expect(res.body.success).toBe(false);
  expect(res.body.error.code).toBe('UNAUTHENTICATED');
}

describe('requireAuth', () => {
  it('accepts a valid token and exposes the user id', async () => {
    const { accessToken } = tokens.sign(USER_ID);
    const res = await get(`Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.userId).toBe(USER_ID);
  });

  it('accepts a lower-case "bearer" scheme', async () => {
    const { accessToken } = tokens.sign(USER_ID);
    expect((await get(`bearer ${accessToken}`)).status).toBe(200);
  });

  describe('missing or malformed', () => {
    it('rejects a request with no Authorization header', async () => {
      expectUnauthenticated(await get());
    });

    it.each([
      ['wrong scheme', 'Token abc.def.ghi'],
      ['no token', 'Bearer'],
      ['no token after space', 'Bearer '],
      ['extra parts', 'Bearer abc def'],
      ['basic auth', 'Basic dXNlcjpwYXNz'],
      ['not a jwt', 'Bearer not-a-jwt'],
    ])('rejects %s', async (_label, header) => {
      expectUnauthenticated(await get(header));
    });
  });

  describe('invalid tokens', () => {
    it('rejects an expired token with a "session expired" message', async () => {
      const expired = jwt.sign({}, TEST_JWT_SECRET, {
        algorithm: 'HS256',
        subject: USER_ID,
        expiresIn: -10,
      });
      const res = await get(`Bearer ${expired}`);
      expectUnauthenticated(res);
      expect(res.body.error.message).toMatch(/expired/i);
    });

    it('rejects a token with a tampered payload', async () => {
      const [header, , signature] = tokens.sign(USER_ID).accessToken.split('.');
      const forgedPayload = Buffer.from(
        JSON.stringify({ sub: 'attacker-id', exp: Math.floor(Date.now() / 1000) + 3600 }),
      ).toString('base64url');
      expectUnauthenticated(await get(`Bearer ${header}.${forgedPayload}.${signature}`));
    });

    it('rejects a token with a tampered signature', async () => {
      const token = tokens.sign(USER_ID).accessToken;
      const tampered = token.slice(0, -4) + (token.endsWith('AAAA') ? 'BBBB' : 'AAAA');
      expectUnauthenticated(await get(`Bearer ${tampered}`));
    });

    it('rejects a token signed with a different secret', async () => {
      const forged = jwt.sign({}, 'a-completely-different-secret-0123456789', {
        subject: USER_ID,
        expiresIn: 3600,
      });
      expectUnauthenticated(await get(`Bearer ${forged}`));
    });

    it('rejects an unsigned "alg: none" token', async () => {
      const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
      const none = `${b64({ alg: 'none', typ: 'JWT' })}.${b64({
        sub: USER_ID,
        exp: Math.floor(Date.now() / 1000) + 3600,
      })}.`;
      expectUnauthenticated(await get(`Bearer ${none}`));
    });

    it('rejects a token signed with a different HMAC algorithm', async () => {
      const hs512 = jwt.sign({}, TEST_JWT_SECRET, {
        algorithm: 'HS512',
        subject: USER_ID,
        expiresIn: 3600,
      });
      expectUnauthenticated(await get(`Bearer ${hs512}`));
    });

    it('rejects a validly signed token that has no subject', async () => {
      const noSubject = jwt.sign({}, TEST_JWT_SECRET, { algorithm: 'HS256', expiresIn: 3600 });
      expectUnauthenticated(await get(`Bearer ${noSubject}`));
    });
  });

  it('getAuth refuses on a route that was not protected', async () => {
    const res = await request(app).get('/t/unprotected');
    expectUnauthenticated(res);
  });
});
