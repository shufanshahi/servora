import jwt from 'jsonwebtoken';
import type { Config } from '../../config';
import { AppError, unauthenticated } from '../../http/errors';

export interface IssuedToken {
  accessToken: string;
  /** ISO timestamp when the token stops being valid. */
  expiresAt: string;
}

/** Signs and verifies access tokens. The only thing in a token is the user id. */
export class TokenService {
  private readonly secret: string;
  private readonly expiresInSeconds: number;

  constructor(config: Pick<Config, 'JWT_SECRET' | 'JWT_EXPIRES_IN_SECONDS'>) {
    this.secret = config.JWT_SECRET;
    this.expiresInSeconds = config.JWT_EXPIRES_IN_SECONDS;
  }

  sign(userId: string): IssuedToken {
    const accessToken = jwt.sign({}, this.secret, {
      algorithm: 'HS256',
      subject: userId,
      expiresIn: this.expiresInSeconds,
    });
    const { exp } = jwt.decode(accessToken) as { exp: number };
    return { accessToken, expiresAt: new Date(exp * 1000).toISOString() };
  }

  /** Returns the user id, or throws 401 UNAUTHENTICATED for any invalid token. */
  verify(token: string): { userId: string } {
    try {
      // Pin the algorithm so a token cannot choose a weaker one (or "none").
      const payload = jwt.verify(token, this.secret, { algorithms: ['HS256'] });
      if (typeof payload === 'string' || typeof payload.sub !== 'string') {
        throw unauthenticated('Invalid token');
      }
      return { userId: payload.sub };
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw unauthenticated('Your session has expired. Please sign in again.');
      }
      if (error instanceof AppError) throw error;
      throw unauthenticated('Invalid token');
    }
  }
}
