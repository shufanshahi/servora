import { createDb, type Db } from '../../src/db/pool';
import { TEST_DATABASE_URL } from './env';

/** Opens a pool on the test database. Close it in afterAll. */
export function createTestDb(): Db {
  return createDb(TEST_DATABASE_URL);
}

/**
 * Empties the given tables (and anything referencing them) between tests.
 * Later changes pass their own table names; none exist yet.
 */
export async function truncate(db: Db, tables: string[]): Promise<void> {
  if (tables.length === 0) return;
  const list = tables.map((table) => `"${table}"`).join(', ');
  await db.query(`TRUNCATE ${list} RESTART IDENTITY CASCADE`);
}
