import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { createRateLimiter } from '../src/http/middleware/rate-limit';
import { ok } from '../src/http/response';
import { buildTestApp } from './support/app';

const { app, db } = buildTestApp((a) => {
  a.get('/t/ping', (_req, res) => {
    ok(res, 'pong');
  });
  a.post('/t/echo', (req, res) => {
    ok(res, req.body);
  });
  a.get('/t/limited', createRateLimiter({ windowMs: 60_000, limit: 3 }), (_req, res) => {
    ok(res, 'fine');
  });
});

afterAll(() => db.close());

describe('baseline security', () => {
  it('sets helmet headers and hides x-powered-by', async () => {
    const res = await request(app).get('/t/ping');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  it('allows configured origins through CORS and omits headers for others', async () => {
    const allowed = await request(app).get('/t/ping').set('Origin', 'http://allowed.test');
    expect(allowed.headers['access-control-allow-origin']).toBe('http://allowed.test');
    const denied = await request(app).get('/t/ping').set('Origin', 'http://evil.test');
    expect(denied.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('serves requests without an Origin header (mobile app, curl)', async () => {
    const res = await request(app).get('/t/ping');
    expect(res.status).toBe(200);
  });

  it('rejects oversized JSON bodies with 413 PAYLOAD_TOO_LARGE', async () => {
    const res = await request(app)
      .post('/t/echo')
      .send({ blob: 'x'.repeat(200 * 1024) });
    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('PAYLOAD_TOO_LARGE');
  });

  it('answers 429 RATE_LIMITED past the limit', async () => {
    for (let i = 0; i < 3; i++) {
      expect((await request(app).get('/t/limited')).status).toBe(200);
    }
    const res = await request(app).get('/t/limited');
    expect(res.status).toBe(429);
    expect(res.body).toEqual({
      success: false,
      error: { code: 'RATE_LIMITED', message: expect.any(String) },
    });
  });
});
