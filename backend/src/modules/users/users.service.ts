import bcrypt from 'bcrypt';
import type { Config } from '../../config';
import { invalidCredentials, unauthenticated, validationError } from '../../http/errors';
import { toPublicUser, type PublicUser, type UsersRepository } from './users.repository';
import type { ChangePasswordInput, UpdateProfileInput } from './users.schemas';

export class UsersService {
  private readonly cost: number;

  constructor(
    config: Pick<Config, 'BCRYPT_COST'>,
    private readonly users: UsersRepository,
  ) {
    this.cost = config.BCRYPT_COST;
  }

  async getMe(userId: string): Promise<PublicUser> {
    const user = await this.users.findById(userId);
    // A valid token for an account that no longer exists is no longer a valid session.
    if (!user) throw unauthenticated('Account no longer exists');
    return toPublicUser(user);
  }

  async updateMe(userId: string, input: UpdateProfileInput): Promise<PublicUser> {
    const user = await this.users.updateProfile(userId, input);
    if (!user) throw unauthenticated('Account no longer exists');
    return toPublicUser(user);
  }

  async changePassword(userId: string, input: ChangePasswordInput): Promise<void> {
    const user = await this.users.findById(userId);
    if (!user) throw unauthenticated('Account no longer exists');

    const matches = await bcrypt.compare(input.currentPassword, user.passwordHash);
    if (!matches) throw invalidCredentials();

    if (input.currentPassword === input.newPassword) {
      throw validationError([
        { field: 'newPassword', message: 'New password must be different from the current one' },
      ]);
    }
    await this.users.updatePasswordHash(userId, await bcrypt.hash(input.newPassword, this.cost));
  }
}
