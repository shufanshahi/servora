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
        '/services/{id}/availability',
        '/appointments',
        '/appointments/{id}',
        '/appointments/{id}/cancel',
        '/users/me',
        '/users/me/password',
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

  it('documents the booking endpoints with their error responses', async () => {
    const api = await SwaggerParser.dereference(specPath);
    const paths = api.paths as unknown as Record<
      string,
      Record<string, { responses: Record<string, unknown>; security?: unknown[] }>
    >;
    const codes = (path: string, method: string) =>
      Object.keys(paths[path]?.[method]?.responses ?? {});
    expect(codes('/services/{id}/availability', 'get')).toEqual(
      expect.arrayContaining(['200', '404', '422']),
    );
    expect(codes('/appointments', 'post')).toEqual(
      expect.arrayContaining(['201', '401', '404', '409', '422']),
    );
    expect(codes('/appointments', 'get')).toEqual(expect.arrayContaining(['200', '401', '422']));
    expect(codes('/appointments/{id}', 'get')).toEqual(
      expect.arrayContaining(['200', '401', '404']),
    );
    expect(codes('/appointments/{id}/cancel', 'patch')).toEqual(
      expect.arrayContaining(['200', '401', '404', '409']),
    );
    // Every appointment operation needs a token; availability is public.
    for (const [path, method] of [
      ['/appointments', 'post'],
      ['/appointments', 'get'],
      ['/appointments/{id}', 'get'],
      ['/appointments/{id}/cancel', 'patch'],
    ] as const) {
      expect(paths[path]?.[method]?.security, `${method} ${path}`).toEqual([{ bearerAuth: [] }]);
    }
    expect(paths['/services/{id}/availability']?.get?.security).toBeUndefined();
  });

  it('documents the profile endpoints, all behind a token', async () => {
    const api = await SwaggerParser.dereference(specPath);
    const paths = api.paths as unknown as Record<
      string,
      Record<string, { responses: Record<string, unknown>; security?: unknown[] }>
    >;
    const codes = (path: string, method: string) =>
      Object.keys(paths[path]?.[method]?.responses ?? {});
    expect(codes('/users/me', 'get')).toEqual(expect.arrayContaining(['200', '401']));
    expect(codes('/users/me', 'patch')).toEqual(expect.arrayContaining(['200', '401', '422']));
    expect(codes('/users/me/password', 'post')).toEqual(
      expect.arrayContaining(['200', '401', '422', '429']),
    );
    for (const [path, method] of [
      ['/users/me', 'get'],
      ['/users/me', 'patch'],
      ['/users/me/password', 'post'],
    ] as const) {
      expect(paths[path]?.[method]?.security, `${method} ${path}`).toEqual([{ bearerAuth: [] }]);
    }
  });

  it('documents the AI chat endpoint behind a token', async () => {
    const api = await SwaggerParser.dereference(specPath);
    const op = (api.paths as unknown as Record<string, Record<string, unknown>>)['/ai/chat']?.[
      'post'
    ] as { responses: Record<string, unknown>; security?: unknown[] };
    expect(Object.keys(op.responses)).toEqual(
      expect.arrayContaining(['200', '401', '422', '429', '503']),
    );
    expect(op.security).toEqual([{ bearerAuth: [] }]);
  });

  it('only mentions error codes that really exist', () => {
    const text = readFileSync(specPath, 'utf8');
    const used = new Set([...text.matchAll(/code: ([A-Z_]+)\b/g)].map((m) => m[1]));
    const known = new Set(Object.values(ERROR_CODES) as string[]);
    for (const code of used)
      expect(known.has(code as string), `${code} is not a real code`).toBe(true);
  });
});
