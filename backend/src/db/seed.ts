import 'dotenv/config';
import { ConfigError, loadConfig } from '../config';
import { createDb } from './pool';
import { DEMO_USER, seedDemoUser } from './seed-users';

/** Fills a local database with demo data. Safe to run repeatedly. */
async function main(): Promise<void> {
  const config = loadConfig();

  // The demo password is public, so never create it on a real deployment.
  if (config.NODE_ENV === 'production' && process.env.SEED_ALLOW_PRODUCTION !== 'true') {
    throw new Error(
      'Refusing to seed demo data when NODE_ENV=production. ' +
        'Set SEED_ALLOW_PRODUCTION=true only if you are certain.',
    );
  }

  const db = createDb(config.DATABASE_URL);
  try {
    await seedDemoUser(db, config.BCRYPT_COST);
    console.log(`Demo user ready: ${DEMO_USER.email} / ${DEMO_USER.password} (local use only)`);
  } finally {
    await db.close();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof ConfigError ? error.message : `Seed failed: ${String(error)}`);
  process.exit(1);
});
