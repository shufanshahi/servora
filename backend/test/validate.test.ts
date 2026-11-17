import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { validate } from '../src/http/middleware/validate';
import { ok } from '../src/http/response';
import { buildTestApp } from './support/app';

const bodySchema = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  age: z.number().int().min(0),
});
const querySchema = z.object({ page: z.coerce.number().int().min(1).default(1) });
const paramsSchema = z.object({ id: z.uuid() });

const { app, db } = buildTestApp((a) => {
  a.post('/t/people', validate({ body: bodySchema }), (req, res) => {
    ok(res, req.body);
  });
  a.get('/t/people', validate({ query: querySchema }), (req, res) => {
    ok(res, req.query);
  });
  a.get('/t/people/:id', validate({ params: paramsSchema }), (req, res) => {
    ok(res, req.params);
  });
});

afterAll(() => db.close());

describe('validate middleware', () => {
  it('returns 422 VALIDATION_ERROR with per-field details', async () => {
    const res = await request(app).post('/t/people').send({ age: 'old' });
    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    const fields = res.body.error.details.map((d: { field: string }) => d.field).sort();
    expect(fields).toEqual(['age', 'name']);
    for (const detail of res.body.error.details) {
      expect(typeof detail.message).toBe('string');
    }
  });

  it('strips unknown fields so they never reach handlers', async () => {
    const res = await request(app)
      .post('/t/people')
      .send({ name: '  Ada  ', age: 36, isAdmin: true, password_hash: 'x' });
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ name: 'Ada', age: 36 });
  });

  it('validates and coerces query parameters', async () => {
    const good = await request(app).get('/t/people?page=3');
    expect(good.body.data).toEqual({ page: 3 });
    const defaulted = await request(app).get('/t/people');
    expect(defaulted.body.data).toEqual({ page: 1 });
    const bad = await request(app).get('/t/people?page=abc');
    expect(bad.status).toBe(422);
    expect(bad.body.error.details[0].field).toBe('query.page');
  });

  it('validates path parameters', async () => {
    const bad = await request(app).get('/t/people/not-a-uuid');
    expect(bad.status).toBe(422);
    expect(bad.body.error.details[0].field).toBe('params.id');
  });
});
