import { describe, expect, it } from 'vitest';
import {
  buildCountQuery,
  buildListQuery,
  escapeLike,
} from '../src/modules/services/services.query';
import {
  listServicesQuery,
  type ListServicesFilters,
} from '../src/modules/services/services.schemas';

const filters = (query: Record<string, unknown> = {}): ListServicesFilters =>
  listServicesQuery.parse(query);

describe('buildListQuery', () => {
  it('lists only active services, by name, one page, by default', () => {
    const { text, values } = buildListQuery(filters());
    expect(text).toContain('WHERE is_active = true');
    expect(text).toContain('ORDER BY name ASC, id ASC');
    expect(text).toMatch(/LIMIT \$1 OFFSET \$2$/);
    expect(values).toEqual([20, 0]);
  });

  it('turns the page number into an offset', () => {
    expect(buildListQuery(filters({ page: '3', limit: '10' })).values).toEqual([10, 20]);
  });

  describe('filters become numbered parameters, in order', () => {
    it('search matches name or description, case-insensitively, with one parameter', () => {
      const { text, values } = buildListQuery(filters({ q: 'Massage' }));
      expect(text).toContain("(name ILIKE $1 ESCAPE '\\' OR description ILIKE $1 ESCAPE '\\')");
      expect(values[0]).toBe('%Massage%');
    });

    it('category is a case-insensitive exact match', () => {
      const { text, values } = buildListQuery(filters({ category: 'wellness' }));
      expect(text).toContain('lower(category) = lower($1)');
      expect(values[0]).toBe('wellness');
    });

    it('prices are compared in whole cents', () => {
      const { text, values } = buildListQuery(filters({ minPrice: '10.5', maxPrice: '49.99' }));
      expect(text).toContain('price_cents >= $1');
      expect(text).toContain('price_cents <= $2');
      expect(values.slice(0, 2)).toEqual([1050, 4999]);
    });

    it('rounds to cents without floating-point drift', () => {
      expect(buildListQuery(filters({ maxPrice: '19.99' })).values[0]).toBe(1999);
      expect(buildListQuery(filters({ maxPrice: '0.07' })).values[0]).toBe(7);
    });

    it('featured true and false', () => {
      expect(buildListQuery(filters({ featured: 'true' })).values[0]).toBe(true);
      expect(buildListQuery(filters({ featured: 'false' })).values[0]).toBe(false);
    });

    it('all filters together keep placeholders and values aligned', () => {
      const { text, values } = buildListQuery(
        filters({
          q: 'a',
          category: 'b',
          minPrice: '1',
          maxPrice: '2',
          featured: 'true',
          page: '2',
          limit: '5',
        }),
      );
      expect(values).toEqual(['%a%', 'b', 100, 200, true, 5, 5]);
      expect(text).toContain('LIMIT $6 OFFSET $7');
      // Every placeholder used in the text has a value.
      const used = [...text.matchAll(/\$(\d+)/g)].map((m) => Number(m[1]));
      expect(Math.max(...used)).toBe(values.length);
    });
  });

  describe('sorting uses a fixed whitelist', () => {
    it.each([
      ['name', 'asc', 'ORDER BY name ASC, id ASC'],
      ['name', 'desc', 'ORDER BY name DESC, id ASC'],
      ['price', 'asc', 'ORDER BY price_cents ASC, name ASC, id ASC'],
      ['price', 'desc', 'ORDER BY price_cents DESC, name ASC, id ASC'],
    ])('sort=%s order=%s', (sort, order, expected) => {
      expect(buildListQuery(filters({ sort, order })).text).toContain(expected);
    });

    it('popular falls back to name order until bookings exist', () => {
      expect(buildListQuery(filters({ sort: 'popular' })).text).toContain(
        'ORDER BY name ASC, id ASC',
      );
      expect(buildListQuery(filters({ sort: 'popular', order: 'desc' })).text).toContain(
        'ORDER BY name ASC, id ASC',
      );
    });
  });

  describe('user input never reaches the SQL text', () => {
    const attacks = [
      "'; DROP TABLE services; --",
      "' OR '1'='1",
      '"; SELECT pg_sleep(10); --',
      '%',
      '\\',
    ];

    it.each(attacks)('search text %j travels only as a parameter', (attack) => {
      const baseline = buildListQuery(filters({ q: 'harmless' })).text;
      const { text, values } = buildListQuery(filters({ q: attack }));
      // The statement is byte-for-byte what a harmless search produces...
      expect(text).toBe(baseline);
      // ...and the input appears only as a (LIKE-escaped) value.
      expect(values[0]).toBe(`%${escapeLike(attack)}%`);
    });

    it.each(attacks)('category %j travels only as a parameter', (attack) => {
      const baseline = buildListQuery(filters({ category: 'harmless' })).text;
      const { text, values } = buildListQuery(filters({ category: attack }));
      expect(text).toBe(baseline);
      expect(values[0]).toBe(attack);
    });

    it('the SQL text is identical whatever the values are', () => {
      const a = buildListQuery(filters({ q: 'one', category: 'two' })).text;
      const b = buildListQuery(filters({ q: "x'; DROP TABLE y;--", category: 'zzz' })).text;
      expect(a).toBe(b);
    });
  });
});

describe('buildCountQuery', () => {
  it('counts with the same filters but no ordering or paging', () => {
    const f = filters({ q: 'a', category: 'b', page: '4', limit: '3' });
    const count = buildCountQuery(f);
    const list = buildListQuery(f);
    expect(count.text).toMatch(/^SELECT count\(\*\)::int AS total FROM services WHERE/);
    expect(count.text).not.toMatch(/ORDER BY|LIMIT|OFFSET/);
    expect(count.values).toEqual(list.values.slice(0, 2)); // filters only, no limit/offset
  });
});

describe('escapeLike', () => {
  it('escapes the LIKE wildcards and the escape character itself', () => {
    expect(escapeLike('50%')).toBe('50\\%');
    expect(escapeLike('a_b')).toBe('a\\_b');
    expect(escapeLike('a\\b')).toBe('a\\\\b');
    expect(escapeLike('plain')).toBe('plain');
  });
});
