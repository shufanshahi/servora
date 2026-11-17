import SwaggerParser from '@apidevtools/swagger-parser';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { seedServices } from '../src/db/seed-services';
import { OPENAPI_PATH } from '../src/http/docs';
import { buildTestApp } from './support/app';
import { resetServices } from './support/services';

const { app, db } = buildTestApp(undefined, {
  env: { PUBLIC_BASE_URL: 'https://api.example.test/' },
});

beforeAll(async () => {
  await resetServices(db);
  await seedServices(db);
});
afterAll(async () => {
  await resetServices(db);
  await db.close();
});

/** The structure of a JSON value: object keys and primitive types, ignoring the values. */
function shapeOf(value: unknown): unknown {
  if (Array.isArray(value)) return value.length > 0 ? [shapeOf(value[0])] : [];
  if (value === null) return 'null';
  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, inner]) => [key, shapeOf(inner)]),
    );
  }
  return typeof value;
}

describe('GET /docs (Swagger UI)', () => {
  it('serves the interactive documentation page', async () => {
    const res = await request(app).get('/docs/');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/text\/html/);
    expect(res.text).toContain('swagger-ui');
  });

  it('serves the UI assets it needs', async () => {
    for (const asset of ['swagger-ui.css', 'swagger-ui-bundle.js', 'swagger-ui-init.js']) {
      const res = await request(app).get(`/docs/${asset}`);
      expect(res.status, asset).toBe(200);
    }
  });

  it('is generated from the OpenAPI file and points "Try it out" at this deployment', async () => {
    const init = (await request(app).get('/docs/swagger-ui-init.js')).text;
    expect(init).toContain('Servora API');
    expect(init).toContain('/services/{id}');
    expect(init).toContain('https://api.example.test'); // PUBLIC_BASE_URL, trailing slash trimmed
    expect(init).not.toContain('api.example.test/"');
  });
});

describe('documented examples match the real API', () => {
  type Operation = {
    responses: Record<string, { content?: Record<string, { example?: unknown }> }>;
  };
  let paths: Record<string, Record<string, Operation>>;

  beforeAll(async () => {
    const api = await SwaggerParser.dereference(OPENAPI_PATH);
    paths = api.paths as unknown as typeof paths;
  });

  const example = (route: string, method: string, status: string) =>
    paths[route]?.[method]?.responses[status]?.content?.['application/json']?.example;

  it('GET /services (200) has the same structure as a real list response', async () => {
    const real = (await request(app).get('/services?limit=1')).body;
    expect(shapeOf(example('/services', 'get', '200'))).toEqual(shapeOf(real));
  });

  it('GET /services/{id} (200) has the same structure as a real detail response', async () => {
    const id = (await request(app).get('/services?limit=1')).body.data[0].id;
    const real = (await request(app).get(`/services/${id}`)).body;
    expect(shapeOf(example('/services/{id}', 'get', '200'))).toEqual(shapeOf(real));
  });

  it('GET /services/{id} (404) has the same structure as a real error', async () => {
    const real = (await request(app).get('/services/not-a-uuid')).body;
    expect(shapeOf(example('/services/{id}', 'get', '404'))).toEqual(shapeOf(real));
    expect(example('/services/{id}', 'get', '404')).toMatchObject({
      error: { code: real.error.code },
    });
  });

  it('GET /services (422) has the same structure as a real validation error', async () => {
    const real = (await request(app).get('/services?minPrice=abc')).body;
    expect(shapeOf(example('/services', 'get', '422'))).toEqual(shapeOf(real));
  });

  it('documents every query parameter the API accepts', () => {
    const op = (paths['/services']?.get ?? {}) as unknown as { parameters: { name: string }[] };
    expect(op.parameters.map((p) => p.name).sort()).toEqual(
      [
        'category',
        'featured',
        'limit',
        'maxPrice',
        'minPrice',
        'order',
        'page',
        'q',
        'sort',
      ].sort(),
    );
  });
});
