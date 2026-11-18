import { DateTime } from 'luxon';
import { z } from 'zod';

export const availabilityQuery = z.object({
  date: z
    .string({ error: 'date is required (YYYY-MM-DD)' })
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be formatted YYYY-MM-DD')
    .refine((value) => DateTime.fromISO(value, { zone: 'utc' }).isValid, 'date is not a real date'),
});

export const createAppointmentBody = z.object({
  serviceId: z.string({ error: 'serviceId is required' }).trim().min(1, 'serviceId is required'),
  startsAt: z
    .string({ error: 'startsAt is required (ISO 8601 with offset)' })
    .refine(
      (value) => /(Z|[+-]\d{2}:\d{2})$/i.test(value) && DateTime.fromISO(value).isValid,
      'startsAt must be an ISO 8601 date-time with a time zone, e.g. 2030-05-06T10:00:00Z',
    ),
  note: z
    .string()
    .trim()
    .max(500, 'note must be at most 500 characters')
    .optional()
    .transform((value) => (value ? value : undefined)),
});
export type CreateAppointmentInput = z.infer<typeof createAppointmentBody>;

export const SCOPES = ['upcoming', 'previous'] as const;
export type Scope = (typeof SCOPES)[number];

export const listAppointmentsQuery = z.object({
  scope: z.enum(SCOPES, { error: `scope must be one of: ${SCOPES.join(', ')}` }).optional(),
  page: z.coerce.number({ error: 'page must be a number' }).int().min(1).max(10_000).default(1),
  limit: z.coerce.number({ error: 'limit must be a number' }).int().min(1).max(50).default(20),
});
export type ListAppointmentsFilters = z.infer<typeof listAppointmentsQuery>;
