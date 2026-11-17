import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import type { Config } from '../config';
import type { Db } from '../db/pool';
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
}

const JSON_BODY_LIMIT = '100kb';

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
  app.use(express.json({ limit: JSON_BODY_LIMIT }));

  app.use(createRoutes({ config, db: deps.db }));
  deps.extraRoutes?.(app);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
