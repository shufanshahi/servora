import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';

const { app, db } = buildTestApp();

afterAll(() => db.close());

describe('GET /health', () => {
  it('returns the success envelope', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('ok');
  });
});
