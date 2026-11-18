import { Router, type RequestHandler } from 'express';
import { getAuth } from '../../http/middleware/require-auth';
import { validate } from '../../http/middleware/validate';
import { ok } from '../../http/response';
import {
  changePasswordBody,
  updateProfileBody,
  type ChangePasswordInput,
  type UpdateProfileInput,
} from './users.schemas';
import type { UsersService } from './users.service';

/** The signed-in user's own account. Every route needs a token and only touches that user. */
export function createUsersRouter(
  service: UsersService,
  requireAuth: RequestHandler,
  passwordLimiter: RequestHandler,
): Router {
  const router = Router();

  router.get('/users/me', requireAuth, async (req, res) => {
    ok(res, await service.getMe(getAuth(req).userId));
  });

  router.patch(
    '/users/me',
    requireAuth,
    validate({ body: updateProfileBody }),
    async (req, res) => {
      ok(res, await service.updateMe(getAuth(req).userId, req.body as UpdateProfileInput));
    },
  );

  // Rate limited like login: this endpoint also checks a password.
  router.post(
    '/users/me/password',
    requireAuth,
    passwordLimiter,
    validate({ body: changePasswordBody }),
    async (req, res) => {
      await service.changePassword(getAuth(req).userId, req.body as ChangePasswordInput);
      ok(res, { changed: true });
    },
  );

  return router;
}
