import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../src/config';

describe('loadConfig', () => {
  it('fails with a readable message when DATABASE_URL is missing', () => {
    expect(() => loadConfig({ NODE_ENV: 'test' })).toThrowError(ConfigError);
    expect(() => loadConfig({ NODE_ENV: 'test' })).toThrowError(/DATABASE_URL/);
  });

  it('applies defaults and parses values', () => {
    const config = loadConfig({
      DATABASE_URL: 'postgres://u:p@localhost:5433/db',
      CORS_ORIGINS: 'http://a.test, http://b.test',
    });
    expect(config.PORT).toBe(3000);
    expect(config.NODE_ENV).toBe('development');
    expect(config.CORS_ORIGINS).toEqual(['http://a.test', 'http://b.test']);
  });

  it('rejects an invalid port', () => {
    expect(() => loadConfig({ DATABASE_URL: 'x', PORT: '99999' })).toThrowError(/PORT/);
  });

  it('returns an immutable object', () => {
    const config = loadConfig({ DATABASE_URL: 'x' });
    expect(Object.isFrozen(config)).toBe(true);
  });
});
