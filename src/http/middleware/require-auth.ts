import type { Request, RequestHandler } from 'express';
import type { TokenService } from '../../modules/auth/token.service';
import { unauthenticated } from '../errors';

export interface AuthContext {
  userId: string;
}

declare module 'express-serve-static-core' {
  interface Request {
    /** Set by requireAuth. Use getAuth(req) to read it with a guarantee. */
    auth?: AuthContext;
  }
}

/** Matches exactly "Bearer <token>" (case-insensitive scheme, single token). */
const BEARER = /^Bearer ([^\s]+)$/i;

/**
 * Protects a route: requires a valid, unexpired bearer token and records who the
 * request is for. Any failure is a 401 UNAUTHENTICATED.
 */
export function createRequireAuth(tokens: TokenService): RequestHandler {
  return (req, _res, next) => {
    const header = req.get('authorization');
    if (!header) {
      next(unauthenticated('Authentication required'));
      return;
    }
    const match = BEARER.exec(header);
    if (!match?.[1]) {
      next(unauthenticated('Malformed Authorization header'));
      return;
    }
    try {
      req.auth = tokens.verify(match[1]);
      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * The authenticated user for this request. Throws 401 if the route was mounted
 * without requireAuth, so handlers never see an undefined user.
 */
export function getAuth(req: Request): AuthContext {
  if (!req.auth) throw unauthenticated('Authentication required');
  return req.auth;
}
