import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { Express, RequestHandler } from 'express';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yaml';
import type { Config } from '../config';
import { notFound } from './errors';

/** The OpenAPI document. Resolves to backend/docs from both src/ and dist/. */
export const OPENAPI_PATH = path.resolve(__dirname, '../../docs/openapi.yaml');

/**
 * Serves interactive API documentation at /docs, generated from docs/openapi.yaml.
 * The "Try it out" server is set to this deployment's own public URL, so the docs work
 * the same locally and when hosted. If the file is missing the API still starts.
 */
export function mountDocs(app: Express, config: Pick<Config, 'PUBLIC_BASE_URL'>): void {
  if (!existsSync(OPENAPI_PATH)) {
    console.warn(`API docs not mounted: ${OPENAPI_PATH} not found`);
    return;
  }
  const spec = YAML.parse(readFileSync(OPENAPI_PATH, 'utf8')) as Record<string, unknown>;
  spec.servers = [{ url: config.PUBLIC_BASE_URL.replace(/\/+$/, ''), description: 'This server' }];

  // The raw specification, handy for importing into Postman or generating a client.
  const yamlText = YAML.stringify(spec);
  app.get('/docs/openapi.json', (_req, res) => {
    res.json(spec);
  });
  app.get('/docs/openapi.yaml', (_req, res) => {
    res.type('application/yaml').send(yamlText);
  });

  // The UI's own files (scripts, styles) are served under /docs, but the interactive page
  // itself answers only at /docs, so any other path is a normal JSON 404.
  const plainFileNamesOnly: RequestHandler = (req, _res, next) => {
    // Only plain file names are looked up. Anything with a path separator (including
    // traversal attempts such as "/../package.json") gets the standard JSON 404 instead
    // of the file server's own plain-text refusal.
    next(/^\/[A-Za-z0-9._-]+$/.test(req.path) || req.path === '/' ? undefined : notFound());
  };
  app.use('/docs', plainFileNamesOnly, swaggerUi.serve);
  app.get(
    '/docs',
    swaggerUi.setup(spec, {
      customSiteTitle: 'Servora API',
      swaggerOptions: { docExpansion: 'list' },
    }),
  );
}
