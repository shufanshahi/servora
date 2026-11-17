import { Router } from 'express';
import { validate } from '../../http/middleware/validate';
import { createServicesController } from './services.controller';
import { listServicesQuery } from './services.schemas';
import type { ServicesService } from './services.service';

/** Public, read-only catalogue endpoints (no authentication). */
export function createServicesRouter(service: ServicesService): Router {
  const router = Router();
  const controller = createServicesController(service);

  router.get('/services', validate({ query: listServicesQuery }), controller.list);
  // No params schema on purpose: a malformed id is a 404, not a 422.
  router.get('/services/:id', controller.get);
  return router;
}
