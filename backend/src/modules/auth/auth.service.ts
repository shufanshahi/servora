import bcrypt from 'bcrypt';
import type { Config } from '../../config';
import { emailTaken, invalidCredentials } from '../../http/errors';
import { toPublicUser, type PublicUser, type UsersRepository } from '../users/users.repository';
import type { LoginInput, RegisterInput } from './auth.schemas';
import type { IssuedToken, TokenService } from './token.service';

export interface AuthResult extends IssuedToken {
  user: PublicUser;
}

const UNIQUE_VIOLATION = '23505';

export class AuthService {
  private readonly cost: number;
  /** Hash compared against when the email is unknown, so timing does not reveal it. */
  private dummyHash: Promise<string> | undefined;

  constructor(
    config: Pick<Config, 'BCRYPT_COST'>,
    private readonly users: UsersRepository,
    private readonly tokens: TokenService,
  ) {
    this.cost = config.BCRYPT_COST;
  }

  async register(input: RegisterInput): Promise<AuthResult> {
    const passwordHash = await bcrypt.hash(input.password, this.cost);
    try {
      const user = await this.users.create({
        name: input.name,
        email: input.email,
        passwordHash,
      });
      return { user: toPublicUser(user), ...this.tokens.sign(user.id) };
    } catch (error) {
      // The unique constraint is the source of truth, so two simultaneous
      // registrations cannot both succeed.
      if ((error as { code?: string }).code === UNIQUE_VIOLATION) throw emailTaken();
      throw error;
    }
  }

  async login(input: LoginInput): Promise<AuthResult> {
    const user = await this.users.findByEmail(input.email);

    // Always run one bcrypt comparison, whether or not the email exists.
    const hash = user?.passwordHash ?? (await this.getDummyHash());
    const matches = await bcrypt.compare(input.password, hash);

    if (!user || !matches) throw invalidCredentials();
    return { user: toPublicUser(user), ...this.tokens.sign(user.id) };
  }

  private getDummyHash(): Promise<string> {
    this.dummyHash ??= bcrypt.hash('not-a-real-password', this.cost);
    return this.dummyHash;
  }
}
