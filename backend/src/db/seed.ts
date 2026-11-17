import 'dotenv/config';
import { ConfigError, loadConfig } from '../config';
import { createDb } from './pool';
import { DEMO_USER, seedDemoUser } from './seed-users';
import { seedServices } from './seed-services';

/** Fills a database with demo data. Safe to run repeatedly. */
async function main(): Promise<void> {
  const config = loadConfig();
  const db = createDb(config.DATABASE_URL);

  try {
    const count = await seedServices(db);
    console.log(`Services ready: ${count} in the catalogue`);

    // The demo password is public, so a real deployment never gets the demo user unless
    // someone says so explicitly.
    if (config.NODE_ENV === 'production' && process.env.SEED_ALLOW_PRODUCTION !== 'true') {
      console.log(
        'Skipped the demo user because NODE_ENV=production (set SEED_ALLOW_PRODUCTION=true to create it).',
      );
      return;
    }
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
