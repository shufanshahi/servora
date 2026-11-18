import type { Request, RequestHandler } from 'express';
import { rateLimit } from 'express-rate-limit';
import { rateLimited } from '../errors';

export interface RateLimitOptions {
  /** Length of the counting window. */
  windowMs: number;
  /** Maximum requests per client in each window. */
  limit: number;
  /** Optional key (defaults to the client IP), e.g. the authenticated user id. */
  keyGenerator?: (req: Request) => string;
}

/** Creates a limiter that answers 429 RATE_LIMITED in the standard error envelope. */
export function createRateLimiter(options: RateLimitOptions): RequestHandler {
  return rateLimit({
    windowMs: options.windowMs,
    limit: options.limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    ...(options.keyGenerator ? { keyGenerator: options.keyGenerator } : {}),
    handler: (_req, _res, next) => next(rateLimited()),
  });
}
