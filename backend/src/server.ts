import 'dotenv/config';
import { ConfigError, loadConfig } from './config';
import { createApp } from './http/app';

function main(): void {
  let config;
  try {
    config = loadConfig();
  } catch (error) {
    if (error instanceof ConfigError) {
      console.error(error.message);
      process.exit(1);
    }
    throw error;
  }

  const app = createApp({ config });
  app.listen(config.PORT, () => {
    console.log(`Servora API listening on port ${config.PORT} (${config.NODE_ENV})`);
  });
}

main();
