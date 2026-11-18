import { IANAZone } from 'luxon';
import { z } from 'zod';

const HH_MM = /^([01]\d|2[0-3]):[0-5]\d$/;

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

  // AI assistant. The key lives only here (never in the app). Without it the feature is
  // disabled and POST /ai/chat answers 503 AI_UNAVAILABLE; the rest of the API is unaffected.
  AI_API_KEY: z
    .string()
    .optional()
    .transform((value) => (value?.trim() ? value.trim() : undefined)),
  AI_MODEL: z.string().min(1).default('gemini-flash-latest'),
  AI_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(15_000),
  AI_MAX_MESSAGE_CHARS: z.coerce.number().int().min(1).max(10_000).default(1000),
  AI_MAX_HISTORY_MESSAGES: z.coerce.number().int().min(0).max(50).default(10),
  AI_RATE_LIMIT_MAX: z.coerce.number().int().min(1).default(20),
  AI_RATE_LIMIT_WINDOW_SECONDS: z.coerce
    .number()
    .int()
    .min(1)
    .default(10 * 60),

  // Booking rules. All times are wall-clock times in BUSINESS_TZ.
  BUSINESS_TZ: z
    .string()
    .default('UTC')
    .refine((value) => IANAZone.isValidZone(value), 'BUSINESS_TZ must be an IANA time zone'),
  BOOKING_OPEN_TIME: z.string().regex(HH_MM, 'must be HH:MM (24-hour)').default('09:00'),
  BOOKING_CLOSE_TIME: z.string().regex(HH_MM, 'must be HH:MM (24-hour)').default('17:00'),
  // Start times sit on a grid of this many minutes.
  SLOT_INTERVAL_MINUTES: z.coerce.number().int().min(5).max(240).default(30),
  // A booking must start at least this many minutes from now.
  MIN_LEAD_MINUTES: z.coerce.number().int().min(0).default(60),
  // ...and no more than this many days ahead.
  BOOKING_HORIZON_DAYS: z.coerce.number().int().min(1).max(365).default(30),
  // How long a booking stays PENDING before it becomes CONFIRMED.
  CONFIRM_DELAY_MINUTES: z.coerce.number().int().min(0).default(2),
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
      if (value.BOOKING_OPEN_TIME >= value.BOOKING_CLOSE_TIME) {
        ctx.addIssue({
          code: 'custom',
          path: ['BOOKING_CLOSE_TIME'],
          message: 'BOOKING_CLOSE_TIME must be later than BOOKING_OPEN_TIME',
        });
      }
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
