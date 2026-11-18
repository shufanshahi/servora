import { describe, expect, it } from 'vitest';
import { listServicesQuery } from '../src/modules/services/services.schemas';

const parse = (query: Record<string, unknown>) => listServicesQuery.safeParse(query);
const ok = (query: Record<string, unknown>) => {
  const result = parse(query);
  if (!result.success) throw new Error(JSON.stringify(result.error.issues));
  return result.data;
};
const fieldsOf = (query: Record<string, unknown>) => {
  const result = parse(query);
  return result.success ? [] : result.error.issues.map((i) => i.path.join('.'));
};

describe('listServicesQuery', () => {
  it('applies defaults when nothing is given', () => {
    expect(ok({})).toEqual({ sort: 'name', order: 'asc', page: 1, limit: 20 });
  });

  it('coerces numbers and booleans from query-string text', () => {
    const q = ok({ minPrice: '10.5', maxPrice: '99', featured: 'true', page: '2', limit: '5' });
    expect(q).toMatchObject({ minPrice: 10.5, maxPrice: 99, featured: true, page: 2, limit: 5 });
    expect(ok({ featured: 'false' }).featured).toBe(false);
  });

  it('trims text and treats blank values as "not given"', () => {
    expect(ok({ q: '  massage  ', category: ' Wellness ' })).toMatchObject({
      q: 'massage',
      category: 'Wellness',
    });
    const blank = ok({ q: '   ', category: '', minPrice: '', featured: '' });
    expect(blank.q).toBeUndefined();
    expect(blank.category).toBeUndefined();
    expect(blank.minPrice).toBeUndefined();
    expect(blank.featured).toBeUndefined();
  });

  describe('rejects bad input', () => {
    it.each(['abc', 'NaN', '1e999x', '12,5'])('non-numeric price %j', (value) => {
      expect(fieldsOf({ minPrice: value })).toContain('minPrice');
      expect(fieldsOf({ maxPrice: value })).toContain('maxPrice');
    });

    it('negative prices', () => {
      expect(fieldsOf({ minPrice: '-1' })).toContain('minPrice');
    });

    it('a minimum above the maximum', () => {
      expect(fieldsOf({ minPrice: '50', maxPrice: '10' })).toContain('minPrice');
      expect(parse({ minPrice: '10', maxPrice: '10' }).success).toBe(true);
    });

    it('an unknown sort or order', () => {
      expect(fieldsOf({ sort: 'price; DROP TABLE services' })).toContain('sort');
      expect(fieldsOf({ sort: 'created_at' })).toContain('sort');
      expect(fieldsOf({ order: 'sideways' })).toContain('order');
    });

    it('a featured value that is not true or false', () => {
      expect(fieldsOf({ featured: 'yes' })).toContain('featured');
    });

    it('out-of-range or non-integer paging', () => {
      expect(fieldsOf({ page: '0' })).toContain('page');
      expect(fieldsOf({ page: '1.5' })).toContain('page');
      expect(fieldsOf({ limit: '0' })).toContain('limit');
      expect(fieldsOf({ limit: '51' })).toContain('limit');
      expect(fieldsOf({ limit: 'many' })).toContain('limit');
    });

    it('over-long text and repeated parameters', () => {
      expect(fieldsOf({ q: 'x'.repeat(101) })).toContain('q');
      expect(fieldsOf({ category: 'x'.repeat(51) })).toContain('category');
      expect(fieldsOf({ q: ['a', 'b'] })).toContain('q');
    });
  });

  it('accepts every documented sort', () => {
    for (const sort of ['name', 'price', 'popular']) expect(ok({ sort }).sort).toBe(sort);
  });

  it('drops unknown parameters', () => {
    expect(ok({ q: 'x', secret: 'y' })).not.toHaveProperty('secret');
  });
});
