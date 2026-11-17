import { z } from 'zod';

/** bcrypt only uses the first 72 bytes, so longer passwords are rejected, not silently cut. */
const MAX_PASSWORD_BYTES = 72;

const name = z
  .string({ error: 'Name is required' })
  .trim()
  .min(1, 'Name is required')
  .max(100, 'Name must be at most 100 characters');

const email = z
  .string({ error: 'Email is required' })
  .trim()
  .toLowerCase()
  .pipe(z.email('Enter a valid email address').max(254, 'Email is too long'));

export const passwordRules = z
  .string({ error: 'Password is required' })
  .min(8, 'Password must be at least 8 characters')
  .refine((value) => /[A-Za-z]/.test(value), 'Password must contain a letter')
  .refine((value) => /\d/.test(value), 'Password must contain a number')
  .refine(
    (value) => Buffer.byteLength(value, 'utf8') <= MAX_PASSWORD_BYTES,
    `Password must be at most ${MAX_PASSWORD_BYTES} bytes`,
  );

export const registerBody = z.object({ name, email, password: passwordRules });

/**
 * Login only checks the shape. It deliberately does not repeat the strength rules, so
 * the response never hints at what a valid password looks like.
 */
export const loginBody = z.object({
  email: z
    .string({ error: 'Email is required' })
    .trim()
    .toLowerCase()
    .min(1, 'Email is required')
    .max(254),
  password: z.string({ error: 'Password is required' }).min(1, 'Password is required').max(200),
});

export type RegisterInput = z.infer<typeof registerBody>;
export type LoginInput = z.infer<typeof loginBody>;
