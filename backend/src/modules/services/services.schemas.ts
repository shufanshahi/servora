import { z } from 'zod';

/** Query-string values arrive as text, and an empty value (`?q=`) means "not given". */
const blankToUndefined = (value: unknown) =>
  typeof value === 'string' && value.trim() === '' ? undefined : value;

const text = (max: number) =>
  z.preprocess(
    blankToUndefined,
    z.string().trim().max(max, `Must be at most ${max} characters`).optional(),
  );

const price = (name: string) =>
  z.preprocess(
    blankToUndefined,
    z.coerce
      .number({ error: `${name} must be a number` })
      .min(0, `${name} must not be negative`)
      .max(1_000_000, `${name} is too large`)
      .optional(),
  );

export const SORT_KEYS = ['name', 'price', 'popular'] as const;
export type SortKey = (typeof SORT_KEYS)[number];

export const listServicesQuery = z
  .object({
    /** Case-insensitive text search over name and description. */
    q: text(100),
    category: text(50),
    minPrice: price('minPrice'),
    maxPrice: price('maxPrice'),
    featured: z.preprocess(
      blankToUndefined,
      z
        .enum(['true', 'false'], { error: 'featured must be true or false' })
        .transform((value) => value === 'true')
        .optional(),
    ),
    sort: z
      .enum(SORT_KEYS, { error: `sort must be one of: ${SORT_KEYS.join(', ')}` })
      .default('name'),
    order: z.enum(['asc', 'desc'], { error: 'order must be asc or desc' }).default('asc'),
    page: z.coerce.number({ error: 'page must be a number' }).int().min(1).max(10_000).default(1),
    limit: z.coerce.number({ error: 'limit must be a number' }).int().min(1).max(50).default(20),
  })
  .refine(
    (value) =>
      value.minPrice === undefined ||
      value.maxPrice === undefined ||
      value.minPrice <= value.maxPrice,
    { path: ['minPrice'], message: 'minPrice must not be greater than maxPrice' },
  );

export type ListServicesFilters = z.infer<typeof listServicesQuery>;
