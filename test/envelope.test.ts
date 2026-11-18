import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { created, ok } from '../src/http/response';
import { buildTestApp } from './support/app';

const { app, db } = buildTestApp((a) => {
  a.get('/t/one', (_req, res) => {
    ok(res, { id: 'abc', name: 'Thing' });
  });
  a.get('/t/list', (_req, res) => {
    ok(res, [{ id: 1 }, { id: 2 }], { page: 1, limit: 20, total: 2 });
  });
  a.post('/t/create', (_req, res) => {
    created(res, { id: 'new' });
  });
});

afterAll(() => db.close());

describe('success envelope', () => {
  it('wraps a single resource as exactly { success, data }', async () => {
    const res = await request(app).get('/t/one');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: { id: 'abc', name: 'Thing' } });
  });

  it('adds pagination meta to list responses', async () => {
    const res = await request(app).get('/t/list');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      success: true,
      data: [{ id: 1 }, { id: 2 }],
      meta: { page: 1, limit: 20, total: 2 },
    });
  });

  it('uses status 201 for created resources', async () => {
    const res = await request(app).post('/t/create');
    expect(res.status).toBe(201);
    expect(res.body).toEqual({ success: true, data: { id: 'new' } });
  });
});
