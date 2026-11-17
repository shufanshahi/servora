import type { RequestHandler } from 'express';
import { ok } from '../../http/response';
import type { ListServicesFilters } from './services.schemas';
import type { ServicesService } from './services.service';

export function createServicesController(service: ServicesService) {
  const list: RequestHandler = async (req, res) => {
    const { items, meta } = await service.list(req.query as unknown as ListServicesFilters);
    ok(res, items, meta);
  };

  const get: RequestHandler = async (req, res) => {
    ok(res, await service.get(String(req.params.id)));
  };

  return { list, get };
}
