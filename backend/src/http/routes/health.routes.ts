import { Router } from 'express';
import { ok } from '../response';

export const healthRouter = Router();

healthRouter.get('/health', (_req, res) => {
  ok(res, { status: 'ok', uptimeSeconds: Math.round(process.uptime()) });
});
