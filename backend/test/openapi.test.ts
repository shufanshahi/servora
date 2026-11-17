import { readFileSync } from 'node:fs';
import path from 'node:path';
import SwaggerParser from '@apidevtools/swagger-parser';
import { describe, expect, it } from 'vitest';
import { ERROR_CODES } from '../src/http/errors';

const specPath = path.resolve(__dirname, '../docs/openapi.yaml');

describe('docs/openapi.yaml', () => {
  it('is a valid OpenAPI document with every $ref resolvable', async () => {
    const api = await SwaggerParser.validate(specPath);
    expect(api.info.title).toBe('Servora API');
  });

  it('documents the auth endpoints', async () => {
    const api = await SwaggerParser.dereference(specPath);
    const paths = api.paths as unknown as Record<
      string,
      Record<string, { responses: Record<string, unknown> }>
    >;
    expect(Object.keys(paths)).toEqual(
      expect.arrayContaining([
        '/health',
        '/auth/register',
        '/auth/login',
        '/services',
        '/services/{id}',
      ]),
    );
    expect(Object.keys(paths['/services']?.get?.responses ?? {})).toEqual(
      expect.arrayContaining(['200', '422']),
    );
    expect(Object.keys(paths['/services/{id}']?.get?.responses ?? {})).toEqual(
      expect.arrayContaining(['200', '404']),
    );
    expect(Object.keys(paths['/auth/register']?.post?.responses ?? {})).toEqual(
      expect.arrayContaining(['201', '409', '422', '429']),
    );
    expect(Object.keys(paths['/auth/login']?.post?.responses ?? {})).toEqual(
      expect.arrayContaining(['200', '401', '422', '429']),
    );
  });

  it('only mentions error codes that really exist', () => {
    const text = readFileSync(specPath, 'utf8');
    const used = new Set([...text.matchAll(/code: ([A-Z_]+)\b/g)].map((m) => m[1]));
    const known = new Set(Object.values(ERROR_CODES) as string[]);
    for (const code of used)
      expect(known.has(code as string), `${code} is not a real code`).toBe(true);
  });
});
