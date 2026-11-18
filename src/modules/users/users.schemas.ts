import { z } from 'zod';
import { passwordRules } from '../auth/auth.schemas';

/** Digits with the usual separators, optional leading +. Permissive on purpose. */
const PHONE_PATTERN = /^\+?[0-9(][0-9 ()\-.]*$/;

const name = z
  .string({ error: 'Name is required' })
  .trim()
  .min(1, 'Name is required')
  .max(100, 'Name must be at most 100 characters');

const digitCount = (value: string): number => value.replace(/\D/g, '').length;

/** An empty string or null clears the number; anything else must look like a phone number. */
const phone = z
  .string({ error: 'Phone must be text' })
  .trim()
  .nullable()
  .transform((value) => (value === '' ? null : value))
  .refine(
    (value) =>
      value === null ||
      (PHONE_PATTERN.test(value) &&
        digitCount(value) >= 6 &&
        digitCount(value) <= 15 &&
        value.length <= 30),
    'Enter a valid phone number (6 to 15 digits, for example +1 555 123 4567)',
  );

/**
 * Only name and phone can be changed here. Anything else in the body (id, email,
 * password, role...) is dropped by the parser and never reaches the database.
 */
export const updateProfileBody = z.object({
  name: name.optional(),
  phone: phone.optional(),
});

export const changePasswordBody = z.object({
  currentPassword: z
    .string({ error: 'Current password is required' })
    .min(1, 'Current password is required')
    .max(200),
  newPassword: passwordRules,
});

export type UpdateProfileInput = z.infer<typeof updateProfileBody>;
export type ChangePasswordInput = z.infer<typeof changePasswordBody>;
