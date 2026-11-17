import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { Express } from 'express';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yaml';
import type { Config } from '../config';

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

  app.use(
    '/docs',
    swaggerUi.serve,
    swaggerUi.setup(spec, {
      customSiteTitle: 'Servora API',
      swaggerOptions: { docExpansion: 'list' },
    }),
  );
}
