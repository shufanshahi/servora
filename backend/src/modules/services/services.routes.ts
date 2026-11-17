import { Router } from 'express';
import { ok } from '../../http/response';
import { validate } from '../../http/middleware/validate';
import { createServicesController } from './services.controller';
import { listServicesQuery } from './services.schemas';
import type { AppointmentsService } from '../appointments/appointments.service';
import { availabilityQuery } from '../appointments/appointments.schemas';
import type { ServicesService } from './services.service';

/** Public, read-only catalogue endpoints (no authentication). */
export function createServicesRouter(
  service: ServicesService,
  appointments: AppointmentsService,
): Router {
  const router = Router();
  const controller = createServicesController(service);

  router.get('/services', validate({ query: listServicesQuery }), controller.list);
  // No params schema on purpose: a malformed id is a 404, not a 422.
  router.get('/services/:id', controller.get);
  // Slot availability lives under the service it describes.
  router.get(
    '/services/:id/availability',
    validate({ query: availabilityQuery }),
    async (req, res) => {
      const { date } = req.query as unknown as { date: string };
      ok(res, await appointments.availability(String(req.params.id), date));
    },
  );
  return router;
}
