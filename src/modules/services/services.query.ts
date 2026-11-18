import type { ListServicesFilters, SortKey } from './services.schemas';

export interface BuiltQuery {
  text: string;
  values: unknown[];
}

/**
 * ORDER BY fragments, chosen from a fixed whitelist. User input only ever selects a
 * key here and is never placed into the SQL text, so it cannot inject anything.
 * `id` is the final tie-breaker so paging is stable.
 */
const POPULAR =
  "(SELECT count(*) FROM appointments a WHERE a.service_id = services.id AND a.status <> 'CANCELLED') DESC, name ASC, id ASC";

const ORDER_BY: Record<SortKey, Record<'asc' | 'desc', string>> = {
  name: { asc: 'name ASC, id ASC', desc: 'name DESC, id ASC' },
  price: { asc: 'price_cents ASC, name ASC, id ASC', desc: 'price_cents DESC, name ASC, id ASC' },
  // Most-booked first, whatever `order` says: "popular" has no useful ascending form.
  // Cancelled bookings do not count. Ties fall back to name order.
  popular: { asc: POPULAR, desc: POPULAR },
};

/** Escapes LIKE wildcards so a search for "50%" matches the text "50%", not everything. */
export function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

const toCents = (dollars: number) => Math.round(dollars * 100);

/** The WHERE clause and its parameters, shared by the page query and the count query. */
function buildWhere(filters: ListServicesFilters): { clause: string; values: unknown[] } {
  const conditions = ['is_active = true'];
  const values: unknown[] = [];
  const add = (condition: (placeholder: string) => string, value: unknown) => {
    values.push(value);
    conditions.push(condition(`$${values.length}`));
  };

  if (filters.q !== undefined) {
    add(
      (p) => `(name ILIKE ${p} ESCAPE '\\' OR description ILIKE ${p} ESCAPE '\\')`,
      `%${escapeLike(filters.q)}%`,
    );
  }
  if (filters.category !== undefined) {
    add((p) => `lower(category) = lower(${p})`, filters.category);
  }
  if (filters.minPrice !== undefined) {
    add((p) => `price_cents >= ${p}`, toCents(filters.minPrice));
  }
  if (filters.maxPrice !== undefined) {
    add((p) => `price_cents <= ${p}`, toCents(filters.maxPrice));
  }
  if (filters.featured !== undefined) {
    add((p) => `is_featured = ${p}`, filters.featured);
  }
  return { clause: `WHERE ${conditions.join(' AND ')}`, values };
}

const COLUMNS =
  'id, name, description, category, price_cents, duration_minutes, image_path, is_featured';

/** The query for one page of services. */
export function buildListQuery(filters: ListServicesFilters): BuiltQuery {
  const { clause, values } = buildWhere(filters);
  const orderBy = ORDER_BY[filters.sort][filters.order];
  values.push(filters.limit, (filters.page - 1) * filters.limit);
  return {
    text:
      `SELECT ${COLUMNS} FROM services ${clause} ORDER BY ${orderBy} ` +
      `LIMIT $${values.length - 1} OFFSET $${values.length}`,
    values,
  };
}

/** The query for how many services match, ignoring paging. */
export function buildCountQuery(filters: ListServicesFilters): BuiltQuery {
  const { clause, values } = buildWhere(filters);
  return { text: `SELECT count(*)::int AS total FROM services ${clause}`, values };
}
