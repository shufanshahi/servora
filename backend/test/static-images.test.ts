import { readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { seedServices } from '../src/db/seed-services';
import { buildTestApp } from './support/app';
import { resetServices } from './support/services';

const BASE = 'https://api.example.test';
const { app, db } = buildTestApp(undefined, { env: { PUBLIC_BASE_URL: `${BASE}/` } });
const imagesDir = path.resolve(__dirname, '../public/images/services');

beforeAll(async () => {
  await resetServices(db);
  await seedServices(db);
});
afterAll(async () => {
  await resetServices(db);
  await db.close();
});

describe('serving the service images', () => {
  it('serves a known image with an image content type and the right bytes', async () => {
    const res = await request(app).get('/images/services/swedish-massage.jpg');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('image/jpeg');
    const onDisk = statSync(path.join(imagesDir, 'swedish-massage.jpg')).size;
    expect(Number(res.headers['content-length'])).toBe(onDisk);
    expect(res.body.length).toBe(onDisk);
    expect(
      Buffer.compare(res.body, readFileSync(path.join(imagesDir, 'swedish-massage.jpg'))),
    ).toBe(0);
  });

  it('serves every imageUrl the API returns, built from PUBLIC_BASE_URL', async () => {
    const list = await request(app).get('/services?limit=50');
    expect(list.body.data).toHaveLength(10);
    for (const service of list.body.data as { name: string; imageUrl: string }[]) {
      expect(service.imageUrl, service.name).toMatch(
        new RegExp(`^${BASE}/images/services/[a-z-]+\\.jpg$`),
      );
      // The app would fetch this absolute URL; here the same path is requested from the test app.
      const res = await request(app).get(new URL(service.imageUrl).pathname);
      expect(res.status, service.imageUrl).toBe(200);
      expect(res.headers['content-type'], service.imageUrl).toMatch(/^image\/jpeg/);
    }
  });

  it('supports HEAD and sets caching and cross-origin headers', async () => {
    const res = await request(app).head('/images/services/manicure.jpg');
    expect(res.status).toBe(200);
    expect(res.headers['cache-control']).toMatch(/max-age=\d+/);
    expect(res.headers['cross-origin-resource-policy']).toBe('cross-origin');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('answers 404 in the JSON envelope for a missing image', async () => {
    const res = await request(app).get('/images/services/does-not-exist.jpg');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  describe('exposes nothing else', () => {
    it('does not list directories', async () => {
      for (const url of ['/images/services/', '/images/services', '/images/', '/']) {
        const res = await request(app).get(url);
        expect(res.headers['content-type'] ?? '', url).not.toMatch(/text\/html/);
        expect(res.text ?? '', url).not.toMatch(/swedish-massage\.jpg/);
      }
    });

    it.each([
      '/images/services/../../package.json',
      '/images/services/%2e%2e/%2e%2e/package.json',
      '/images/services/..%2f..%2fpackage.json',
      '/images/services/..%2F..%2F.env',
      '/%2e%2e/src/server.ts',
      '/images/services/%00.jpg',
    ])('blocks path traversal: %s', async (url) => {
      const res = await request(app).get(url);
      expect([400, 403, 404]).toContain(res.status);
      expect(res.text ?? '').not.toContain('servora-backend');
      expect(res.text ?? '').not.toContain('JWT_SECRET');
    });

    it('does not serve dotfiles', async () => {
      const res = await request(app).get('/.env');
      expect(res.status).toBe(404);
    });

    it('does not serve source or config from outside public/', async () => {
      for (const url of [
        '/package.json',
        '/src/server.ts',
        '/openapi.yaml', // only the documented /docs/openapi.yaml route exists
        '/.env.example',
        '/docs/../package.json',
      ]) {
        const res = await request(app).get(url);
        expect(res.status, url).toBe(404);
      }
    });
  });
});
