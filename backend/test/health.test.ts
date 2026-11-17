import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config';
import { createApp } from '../src/http/app';
import { TEST_DATABASE_URL } from './support/env';
import { createTestDb } from './support/db';

const db = createTestDb();
const app = createApp({
  config: loadConfig({ DATABASE_URL: TEST_DATABASE_URL, NODE_ENV: 'test' }),
  db,
});

afterAll(() => db.close());

describe('GET /health', () => {
  it('returns the success envelope', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('ok');
  });
});
