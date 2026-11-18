import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { ok } from '../src/http/response';
import { buildTestApp } from './support/app';

const lines: string[] = [];
const { app, db } = buildTestApp(
  (a) => {
    a.post('/t/login', (req, res) => {
      ok(res, { received: Object.keys(req.body) });
    });
  },
  { logSink: (line) => lines.push(line) },
);

afterAll(() => db.close());

describe('request logging', () => {
  it('logs method, path and status but never bodies, headers or query strings', async () => {
    await request(app)
      .post('/t/login?token=query-secret-789')
      .set('Authorization', 'Bearer header-secret-456')
      .send({ email: 'a@b.test', password: 'p4ssw0rd-secret-123' });

    expect(lines).toHaveLength(1);
    expect(lines[0]).toMatch(/^POST \/t\/login 200 [\d.]+ms$/);
    const all = lines.join('\n');
    expect(all).not.toContain('p4ssw0rd-secret-123');
    expect(all).not.toContain('header-secret-456');
    expect(all).not.toContain('query-secret-789');
    expect(all).not.toContain('a@b.test');
  });
});
