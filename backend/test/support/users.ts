import type { Db } from '../../src/db/pool';

/** Empties the users table (and anything that references it) between tests. */
export async function resetUsers(db: Db): Promise<void> {
  await db.query('TRUNCATE users RESTART IDENTITY CASCADE');
}

export const validUser = {
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  password: 'Sup3rSecret',
};
