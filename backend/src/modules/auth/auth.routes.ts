import { Router, type RequestHandler } from 'express';
import { validate } from '../../http/middleware/validate';
import { createAuthController } from './auth.controller';
import { loginBody, registerBody } from './auth.schemas';
import type { AuthService } from './auth.service';

export function createAuthRouter(service: AuthService, limiter: RequestHandler): Router {
  const router = Router();
  const controller = createAuthController(service);

  // One shared limiter: every register or login attempt from an IP counts toward it.
  router.post('/auth/register', limiter, validate({ body: registerBody }), controller.register);
  router.post('/auth/login', limiter, validate({ body: loginBody }), controller.login);
  return router;
}
