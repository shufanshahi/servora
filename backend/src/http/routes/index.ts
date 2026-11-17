import { Router } from 'express';
import type { Config } from '../../config';
import type { Db } from '../../db/pool';
import { createAuthRouter } from '../../modules/auth/auth.routes';
import { AuthService } from '../../modules/auth/auth.service';
import { TokenService } from '../../modules/auth/token.service';
import { UsersRepository } from '../../modules/users/users.repository';
import { createRateLimiter } from '../middleware/rate-limit';
import { healthRouter } from './health.routes';

export interface RouteDeps {
  config: Config;
  db: Db;
}

/** Wires modules together and returns every route of the API. */
export function createRoutes({ config, db }: RouteDeps): Router {
  const routes = Router();

  const users = new UsersRepository(db);
  const tokens = new TokenService(config);
  const auth = new AuthService(config, users, tokens);

  const authLimiter = createRateLimiter({
    windowMs: config.AUTH_RATE_LIMIT_WINDOW_SECONDS * 1000,
    limit: config.AUTH_RATE_LIMIT_MAX,
  });

  routes.use(healthRouter);
  routes.use(createAuthRouter(auth, authLimiter));
  return routes;
}
