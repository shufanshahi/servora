import { Router, type RequestHandler } from 'express';
import { getAuth } from '../../http/middleware/require-auth';
import { validate } from '../../http/middleware/validate';
import { created, ok } from '../../http/response';
import {
  createAppointmentBody,
  listAppointmentsQuery,
  type CreateAppointmentInput,
  type ListAppointmentsFilters,
} from './appointments.schemas';
import type { AppointmentsService } from './appointments.service';

/** Authenticated appointment endpoints. Every route is scoped to the caller's own data. */
export function createAppointmentsRouter(
  service: AppointmentsService,
  requireAuth: RequestHandler,
): Router {
  const router = Router();

  router.post(
    '/appointments',
    requireAuth,
    validate({ body: createAppointmentBody }),
    async (req, res) => {
      created(res, await service.create(getAuth(req).userId, req.body as CreateAppointmentInput));
    },
  );

  router.get(
    '/appointments',
    requireAuth,
    validate({ query: listAppointmentsQuery }),
    async (req, res) => {
      const { items, meta } = await service.list(
        getAuth(req).userId,
        req.query as unknown as ListAppointmentsFilters,
      );
      ok(res, items, meta);
    },
  );

  // No params schema: a malformed id is a 404, not a 422.
  router.get('/appointments/:id', requireAuth, async (req, res) => {
    ok(res, await service.get(getAuth(req).userId, String(req.params.id)));
  });

  router.patch('/appointments/:id/cancel', requireAuth, async (req, res) => {
    ok(res, await service.cancel(getAuth(req).userId, String(req.params.id)));
  });

  return router;
}
