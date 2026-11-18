import { Router } from 'express';
import type { Config } from '../../config';
import type { Db } from '../../db/pool';
import { createAiRouter } from '../../modules/ai/ai.routes';
import type { AiProvider } from '../../modules/ai/ai.provider';
import { AiService } from '../../modules/ai/ai.service';
import { GeminiProvider } from '../../modules/ai/gemini.provider';
import { createAuthRouter } from '../../modules/auth/auth.routes';
import { AuthService } from '../../modules/auth/auth.service';
import { TokenService } from '../../modules/auth/token.service';
import { AppointmentsRepository } from '../../modules/appointments/appointments.repository';
import { AppointmentsService } from '../../modules/appointments/appointments.service';
import { createAppointmentsRouter } from '../../modules/appointments/appointments.routes';
import { createServicesRouter } from '../../modules/services/services.routes';
import { ServicesRepository } from '../../modules/services/services.repository';
import { ServicesService } from '../../modules/services/services.service';
import { UsersRepository } from '../../modules/users/users.repository';
import { createUsersRouter } from '../../modules/users/users.routes';
import { UsersService } from '../../modules/users/users.service';
import { createRequireAuth, getAuth } from '../middleware/require-auth';
import { createRateLimiter } from '../middleware/rate-limit';
import { healthRouter } from './health.routes';

export interface RouteDeps {
  config: Config;
  db: Db;
  /** Source of "now" for booking rules. */
  clock?: () => Date;
  /** Overrides the provider built from config (tests inject a fake). */
  aiProvider?: AiProvider;
}

/** Wires modules together and returns every route of the API. */
export function createRoutes({
  config,
  db,
  clock = () => new Date(),
  aiProvider,
}: RouteDeps): Router {
  const routes = Router();

  const users = new UsersRepository(db);
  const tokens = new TokenService(config);
  const auth = new AuthService(config, users, tokens);

  const servicesRepository = new ServicesRepository(db);
  const services = new ServicesService(config, servicesRepository);
  const appointments = new AppointmentsService(
    config,
    clock,
    servicesRepository,
    new AppointmentsRepository(db),
  );

  const authLimiter = createRateLimiter({
    windowMs: config.AUTH_RATE_LIMIT_WINDOW_SECONDS * 1000,
    limit: config.AUTH_RATE_LIMIT_MAX,
  });

  const provider =
    aiProvider ??
    (config.AI_API_KEY
      ? new GeminiProvider({
          apiKey: config.AI_API_KEY,
          model: config.AI_MODEL,
          timeoutMs: config.AI_TIMEOUT_MS,
        })
      : undefined);
  const ai = new AiService(config, provider, services);
  // Budget is per signed-in user (this limiter always runs after requireAuth).
  const aiLimiter = createRateLimiter({
    windowMs: config.AI_RATE_LIMIT_WINDOW_SECONDS * 1000,
    limit: config.AI_RATE_LIMIT_MAX,
    keyGenerator: (req) => getAuth(req).userId,
  });

  routes.use(healthRouter);
  routes.use(createAuthRouter(auth, authLimiter));
  routes.use(
    createUsersRouter(new UsersService(config, users), createRequireAuth(tokens), authLimiter),
  );
  routes.use(createServicesRouter(services, appointments));
  routes.use(createAppointmentsRouter(appointments, createRequireAuth(tokens)));
  routes.use(createAiRouter(ai, config, createRequireAuth(tokens), aiLimiter));
  return routes;
}
