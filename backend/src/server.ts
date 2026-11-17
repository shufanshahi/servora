import 'dotenv/config';
import type { Server } from 'node:http';
import { ConfigError, loadConfig, type Config } from './config';
import { createDb } from './db/pool';
import { createApp } from './http/app';
import { startStatusReconciler } from './modules/appointments/status-reconciler';

const SHUTDOWN_TIMEOUT_MS = 10_000;

function readConfig(): Config {
  try {
    return loadConfig();
  } catch (error) {
    if (error instanceof ConfigError) {
      console.error(error.message);
      process.exit(1);
    }
    throw error;
  }
}

async function main(): Promise<void> {
  const config = readConfig();
  const db = createDb(config.DATABASE_URL);

  try {
    await db.query('SELECT 1');
  } catch (error) {
    console.error(`Cannot reach the database: ${(error as Error).message}`);
    await db.close().catch(() => undefined);
    process.exit(1);
  }

  const app = createApp({ config, db });
  const stopReconciler = startStatusReconciler(db, config);
  const server: Server = app.listen(config.PORT, () => {
    console.log(`Servora API listening on port ${config.PORT} (${config.NODE_ENV})`);
  });

  let shuttingDown = false;
  const shutdown = (signal: string): void => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`${signal} received, shutting down`);

    const forceExit = setTimeout(() => {
      console.error('Shutdown timed out, forcing exit');
      process.exit(1);
    }, SHUTDOWN_TIMEOUT_MS);
    forceExit.unref();

    stopReconciler();
    server.close(() => {
      db.close()
        .then(() => process.exit(0))
        .catch((error: Error) => {
          console.error(`Error closing database pool: ${error.message}`);
          process.exit(1);
        });
    });
    server.closeIdleConnections();
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((error) => {
  console.error('Fatal error during startup:', error);
  process.exit(1);
});
