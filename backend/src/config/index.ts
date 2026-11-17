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
  // Secret used to sign access tokens. Must be long and random; generate one with
  //   node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
  JWT_SECRET: z
    .string({ error: 'JWT_SECRET is required (at least 32 characters)' })
    .min(32, 'JWT_SECRET must be at least 32 characters'),
  // Access token lifetime in seconds (default 7 days).
  JWT_EXPIRES_IN_SECONDS: z.coerce
    .number()
    .int()
    .min(60)
    .default(7 * 24 * 60 * 60),
  // bcrypt work factor. 12 is a good default; tests lower it for speed.
  BCRYPT_COST: z.coerce.number().int().min(4).max(15).default(12),
  // Failed-attempt protection on register and login, per client IP.
  AUTH_RATE_LIMIT_MAX: z.coerce.number().int().min(1).default(10),
  AUTH_RATE_LIMIT_WINDOW_SECONDS: z.coerce
    .number()
    .int()
    .min(1)
    .default(15 * 60),
  // Number of reverse proxies in front of the API (0 locally, 1 on most hosts). Needed so
  // rate limiting sees the real client IP instead of the proxy's.
  TRUST_PROXY: z.coerce.number().int().min(0).default(0),
});

/** Every environment variable the API reads (used to keep the docs in step). */
export const CONFIG_KEYS = Object.keys(schema.shape);

/** Prefix of the public example secret in .env.example. Never acceptable in production. */
export const PLACEHOLDER_SECRET_PREFIX = 'dev-only-';

export type Config = Readonly<z.infer<typeof schema>>;

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigError';
  }
}

/** Parses and validates environment variables. Throws ConfigError with a readable message. */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const result = schema
    .superRefine((value, ctx) => {
      if (
        value.NODE_ENV === 'production' &&
        value.JWT_SECRET.startsWith(PLACEHOLDER_SECRET_PREFIX)
      ) {
        ctx.addIssue({
          code: 'custom',
          path: ['JWT_SECRET'],
          message: 'JWT_SECRET is the public development placeholder; set a real random secret',
        });
      }
    })
    .safeParse(env);
  if (!result.success) {
    const lines = result.error.issues.map(
      (issue) => `  - ${issue.path.join('.')}: ${issue.message}`,
    );
    throw new ConfigError(`Invalid environment configuration:\n${lines.join('\n')}`);
  }
  return Object.freeze(result.data);
}
