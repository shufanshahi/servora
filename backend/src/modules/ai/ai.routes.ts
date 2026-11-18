import { Router, type RequestHandler } from 'express';
import type { Config } from '../../config';
import { getAuth } from '../../http/middleware/require-auth';
import { validate } from '../../http/middleware/validate';
import { ok } from '../../http/response';
import { chatBody, type ChatInput } from './ai.schemas';
import type { AiService } from './ai.service';

/** Authenticated, per-user rate-limited chat. Auth and limits run before the provider is touched. */
export function createAiRouter(
  service: AiService,
  config: Pick<Config, 'AI_MAX_MESSAGE_CHARS'>,
  requireAuth: RequestHandler,
  limiter: RequestHandler,
): Router {
  const router = Router();
  router.post(
    '/ai/chat',
    requireAuth,
    limiter,
    validate({ body: chatBody(config.AI_MAX_MESSAGE_CHARS) }),
    async (req, res) => {
      getAuth(req);
      const { message, history } = req.body as ChatInput;
      ok(res, { reply: await service.chat({ message, history }) });
    },
  );
  return router;
}
