import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config';
import { createApp } from '../src/http/app';

const app = createApp({ config: loadConfig({ DATABASE_URL: 'postgres://x', NODE_ENV: 'test' }) });

describe('GET /health', () => {
  it('returns the success envelope', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('ok');
  });
});
