import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z
    .string({ error: 'DATABASE_URL is required (PostgreSQL connection string)' })
    .min(1, 'DATABASE_URL must not be empty'),
  // Comma-separated list of allowed browser origins. The mobile app is not subject to CORS.
  CORS_ORIGINS: z
    .string()
    .default('')
    .transform((value) =>
      value
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean),
    ),
  PUBLIC_BASE_URL: z.string().default('http://localhost:3000'),
  // Number of reverse proxies in front of the API (0 locally, 1 on most hosts). Needed so
  // rate limiting sees the real client IP instead of the proxy's.
  TRUST_PROXY: z.coerce.number().int().min(0).default(0),
});

export type Config = Readonly<z.infer<typeof schema>>;

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigError';
  }
}

/** Parses and validates environment variables. Throws ConfigError with a readable message. */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const result = schema.safeParse(env);
  if (!result.success) {
    const lines = result.error.issues.map(
      (issue) => `  - ${issue.path.join('.')}: ${issue.message}`,
    );
    throw new ConfigError(`Invalid environment configuration:\n${lines.join('\n')}`);
  }
  return Object.freeze(result.data);
}
