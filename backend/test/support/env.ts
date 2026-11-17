/** Connection string for the dedicated test database (never the development one). */
export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? 'postgres://servora:servora@localhost:5433/servora_test';

/** Signing secret for tests only (32+ characters, as the config requires). */
export const TEST_JWT_SECRET = 'test-secret-test-secret-test-secret-1234';

/** Low bcrypt cost keeps password-hashing tests fast. Production uses 12. */
export const TEST_BCRYPT_COST = '4';
