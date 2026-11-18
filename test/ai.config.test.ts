import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config';
import { buildTestApp } from './support/app';
import { TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';

const base = { DATABASE_URL: TEST_DATABASE_URL, JWT_SECRET: TEST_JWT_SECRET };

describe('AI settings', () => {
  it('has safe defaults and treats a missing or blank key as disabled', () => {
    for (const env of [base, { ...base, AI_API_KEY: '' }, { ...base, AI_API_KEY: '   ' }]) {
      const c = loadConfig(env);
      expect(c.AI_API_KEY).toBeUndefined();
      expect(c.AI_MODEL).toBe('gemini-flash-latest');
      expect(c.AI_TIMEOUT_MS).toBe(15_000);
      expect(c.AI_MAX_MESSAGE_CHARS).toBe(1000);
      expect(c.AI_MAX_HISTORY_MESSAGES).toBe(10);
      expect(c.AI_RATE_LIMIT_MAX).toBe(20);
      expect(c.AI_RATE_LIMIT_WINDOW_SECONDS).toBe(600);
    }
  });

  it('reads the key and overrides', () => {
    const c = loadConfig({ ...base, AI_API_KEY: ' k ', AI_MODEL: 'm', AI_TIMEOUT_MS: '5000' });
    expect(c.AI_API_KEY).toBe('k');
    expect(c.AI_MODEL).toBe('m');
    expect(c.AI_TIMEOUT_MS).toBe(5000);
  });

  it('rejects out-of-range values', () => {
    expect(() => loadConfig({ ...base, AI_TIMEOUT_MS: '10' })).toThrowError(/AI_TIMEOUT_MS/);
    expect(() => loadConfig({ ...base, AI_MAX_MESSAGE_CHARS: '0' })).toThrowError(
      /AI_MAX_MESSAGE_CHARS/,
    );
  });
});

describe('startup without a key', () => {
  const { app, db } = buildTestApp();
  afterAll(() => db.close());

  it('does not crash: the API runs and the chat answers 503 AI_UNAVAILABLE', async () => {
    expect((await request(app).get('/health')).status).toBe(200);
    const reg = await request(app)
      .post('/auth/register')
      .send({ name: 'No Key', email: `nokey${Date.now()}@example.com`, password: 'Sup3rSecret' });
    const token = reg.body.data.accessToken as string;
    const res = await request(app)
      .post('/ai/chat')
      .set('Authorization', `Bearer ${token}`)
      .send({ message: 'hello' });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('AI_UNAVAILABLE');
  });
});
