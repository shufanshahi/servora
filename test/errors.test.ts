import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { AppError, conflict, forbidden, notFound, unauthenticated } from '../src/http/errors';
import { registerPgErrorMapper } from '../src/http/middleware/error-handler';
import { buildTestApp } from './support/app';

registerPgErrorMapper('23P01', () => conflict('TEST_CONFLICT', 'Mapped from a database error'));

const { app, db } = buildTestApp((a) => {
  a.get('/t/not-found', () => {
    throw notFound('Thing 42 does not exist');
  });
  a.get('/t/unauth', () => {
    throw unauthenticated();
  });
  a.get('/t/forbidden', () => {
    throw forbidden();
  });
  a.get('/t/async-fail', async () => {
    throw new AppError(418, 'TEAPOT', 'I am a teapot');
  });
  a.get('/t/boom', () => {
    throw new Error('secret internal detail: password=hunter2');
  });
  a.get('/t/pg-mapped', () => {
    throw Object.assign(new Error('exclusion violation'), { code: '23P01' });
  });
  a.get('/t/pg-unmapped', () => {
    throw Object.assign(new Error('relation "users" does not exist'), { code: '42P01' });
  });
});

afterAll(() => db.close());

describe('error handling', () => {
  it('returns 404 NOT_FOUND in the error envelope', async () => {
    const res = await request(app).get('/t/not-found');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({
      success: false,
      error: { code: 'NOT_FOUND', message: 'Thing 42 does not exist' },
    });
  });

  it('returns JSON (not HTML) for an unknown route', async () => {
    const res = await request(app).get('/definitely/not/a/route');
    expect(res.status).toBe(404);
    expect(res.headers['content-type']).toMatch(/application\/json/);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('maps 401 and 403 factories', async () => {
    const a = await request(app).get('/t/unauth');
    expect(a.status).toBe(401);
    expect(a.body.error.code).toBe('UNAUTHENTICATED');
    const b = await request(app).get('/t/forbidden');
    expect(b.status).toBe(403);
    expect(b.body.error.code).toBe('FORBIDDEN');
  });

  it('handles errors thrown from async handlers', async () => {
    const res = await request(app).get('/t/async-fail');
    expect(res.status).toBe(418);
    expect(res.body.error.code).toBe('TEAPOT');
  });

  describe('forced unexpected error', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    beforeAll(() => spy.mockClear());

    it('returns 500 with no stack trace or internal detail', async () => {
      const res = await request(app).get('/t/boom');
      expect(res.status).toBe(500);
      expect(res.body).toEqual({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' },
      });
      const raw = JSON.stringify(res.body) + JSON.stringify(res.headers);
      expect(raw).not.toMatch(/hunter2|secret internal|at .*\.ts|stack/i);
      // The detail is still logged server-side for debugging.
      expect(spy).toHaveBeenCalled();
    });
  });

  it('translates registered PostgreSQL error codes', async () => {
    const res = await request(app).get('/t/pg-mapped');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('TEST_CONFLICT');
  });

  it('treats unmapped PostgreSQL errors as a generic 500', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const res = await request(app).get('/t/pg-unmapped');
    expect(res.status).toBe(500);
    expect(JSON.stringify(res.body)).not.toContain('users');
  });

  it('returns 400 BAD_REQUEST for malformed JSON', async () => {
    const res = await request(app)
      .post('/t/anything')
      .set('Content-Type', 'application/json')
      .send('{"broken":');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('BAD_REQUEST');
  });
});
