import express, { type Express } from 'express';
import type { Config } from '../config';
import { routes } from './routes';

export interface AppDeps {
  config: Config;
}

/** Builds the Express app. Kept separate from server bootstrap so tests can import it. */
export function createApp(_deps: AppDeps): Express {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json());
  app.use(routes);
  return app;
}
