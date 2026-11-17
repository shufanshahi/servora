import type { RequestHandler } from 'express';
import { created, ok } from '../../http/response';
import type { LoginInput, RegisterInput } from './auth.schemas';
import type { AuthService } from './auth.service';

export function createAuthController(service: AuthService) {
  const register: RequestHandler = async (req, res) => {
    created(res, await service.register(req.body as RegisterInput));
  };

  const login: RequestHandler = async (req, res) => {
    ok(res, await service.login(req.body as LoginInput));
  };

  return { register, login };
}
