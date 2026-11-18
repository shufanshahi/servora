import bcrypt from 'bcrypt';
import type { Db } from './pool';

/**
 * Credentials of the demo account created by `npm run seed`.
 * LOCAL DEVELOPMENT ONLY: these are public, so the seed refuses to run in production.
 */
export const DEMO_USER = {
  name: 'Demo User',
  email: 'demo@servora.test',
  password: 'Demo1234',
} as const;

/** Creates the demo user, or resets its name and password if it already exists. */
export async function seedDemoUser(db: Db, bcryptCost: number): Promise<void> {
  const passwordHash = await bcrypt.hash(DEMO_USER.password, bcryptCost);
  await db.query(
    `INSERT INTO users (name, email, password_hash)
     VALUES ($1, $2, $3)
     ON CONFLICT (email)
     DO UPDATE SET name = EXCLUDED.name, password_hash = EXCLUDED.password_hash, updated_at = now()`,
    [DEMO_USER.name, DEMO_USER.email, passwordHash],
  );
}
