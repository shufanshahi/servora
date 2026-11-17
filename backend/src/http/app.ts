import cors from 'cors';
import path from 'node:path';
import express, { type Express } from 'express';
import helmet from 'helmet';
import type { Config } from '../config';
import type { Db } from '../db/pool';
import { mountDocs } from './docs';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { requestLogger, type LogSink } from './middleware/request-logger';
import { createRoutes } from './routes';

export interface AppDeps {
  config: Config;
  db: Db;
  /** Where request log lines go. Defaults to console, and to silent when NODE_ENV is "test". */
  logSink?: LogSink;
  /** Extra routes mounted before the 404 handler. Intended for tests. */
  extraRoutes?: (app: Express) => void;
  /** Source of "now" for booking rules. Defaults to the system clock; tests inject a fixed one. */
  clock?: () => Date;
}

const JSON_BODY_LIMIT = '100kb';

/** Static files (service images). Resolves to backend/public from both src/ and dist/. */
const PUBLIC_DIR = path.resolve(__dirname, '../../public');

/** Builds the Express app. Kept separate from server bootstrap so tests can import it. */
export function createApp(deps: AppDeps): Express {
  const { config } = deps;
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', config.TRUST_PROXY);

  const logSink: LogSink =
    deps.logSink ?? (config.NODE_ENV === 'test' ? () => undefined : (line) => console.log(line));
  app.use(requestLogger(logSink));

  app.use(helmet());
  app.use(
    cors({
      // Requests without an Origin header (the mobile app, curl) are always allowed;
      // browsers are limited to the configured allowlist.
      origin: (origin, callback) =>
        callback(null, origin === undefined || config.CORS_ORIGINS.includes(origin)),
    }),
  );
  app.use(
    express.static(PUBLIC_DIR, {
      index: false, // never produce a directory page
      redirect: false, // a bare directory path is a plain JSON 404, not an HTML redirect
      dotfiles: 'ignore', // .env and friends are invisible
      maxAge: '1d',
      setHeaders: (res) => {
        // helmet defaults to same-origin; images are meant to be embeddable by clients.
        res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
      },
    }),
  );
  app.use(express.json({ limit: JSON_BODY_LIMIT }));

  mountDocs(app, config);
  app.use(createRoutes({ config, db: deps.db, ...(deps.clock ? { clock: deps.clock } : {}) }));
  deps.extraRoutes?.(app);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
