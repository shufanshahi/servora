import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../src/config';
import { TEST_DATABASE_URL, TEST_JWT_SECRET } from './support/env';

const base = { DATABASE_URL: 'postgres://u:p@localhost:5433/db', JWT_SECRET: TEST_JWT_SECRET };

describe('loadConfig', () => {
  it('fails with a readable message when DATABASE_URL is missing', () => {
    expect(() => loadConfig({ NODE_ENV: 'test', JWT_SECRET: TEST_JWT_SECRET })).toThrowError(
      ConfigError,
    );
    expect(() => loadConfig({ NODE_ENV: 'test', JWT_SECRET: TEST_JWT_SECRET })).toThrowError(
      /DATABASE_URL/,
    );
  });

  it('applies defaults and parses values', () => {
    const config = loadConfig({ ...base, CORS_ORIGINS: 'http://a.test, http://b.test' });
    expect(config.PORT).toBe(3000);
    expect(config.NODE_ENV).toBe('development');
    expect(config.CORS_ORIGINS).toEqual(['http://a.test', 'http://b.test']);
    expect(config.JWT_EXPIRES_IN_SECONDS).toBe(7 * 24 * 60 * 60);
    expect(config.BCRYPT_COST).toBe(12);
    expect(config.AUTH_RATE_LIMIT_MAX).toBe(10);
    expect(config.AUTH_RATE_LIMIT_WINDOW_SECONDS).toBe(900);
  });

  it('rejects an invalid port', () => {
    expect(() => loadConfig({ ...base, PORT: '99999' })).toThrowError(/PORT/);
  });

  it('returns an immutable object', () => {
    expect(Object.isFrozen(loadConfig(base))).toBe(true);
  });

  describe('JWT secret', () => {
    it('is required', () => {
      expect(() => loadConfig({ DATABASE_URL: base.DATABASE_URL })).toThrowError(/JWT_SECRET/);
    });

    it('must be at least 32 characters', () => {
      const thirtyOne = 'x'.repeat(31);
      expect(() => loadConfig({ ...base, JWT_SECRET: thirtyOne })).toThrowError(
        /JWT_SECRET must be at least 32 characters/,
      );
      expect(loadConfig({ ...base, JWT_SECRET: 'x'.repeat(32) }).JWT_SECRET).toHaveLength(32);
    });
  });

  it('keeps the bcrypt cost and token lifetime within sane bounds', () => {
    expect(() => loadConfig({ ...base, BCRYPT_COST: '3' })).toThrowError(/BCRYPT_COST/);
    expect(() => loadConfig({ ...base, BCRYPT_COST: '16' })).toThrowError(/BCRYPT_COST/);
    expect(() => loadConfig({ ...base, JWT_EXPIRES_IN_SECONDS: '10' })).toThrowError(
      /JWT_EXPIRES_IN_SECONDS/,
    );
  });
});

describe('server startup with a bad JWT secret', () => {
  it('refuses to start and explains why', () => {
    const root = path.resolve(__dirname, '..');
    const result = spawnSync(process.execPath, ['--import', 'tsx', 'src/server.ts'], {
      cwd: root,
      encoding: 'utf8',
      timeout: 20_000,
      env: {
        PATH: process.env.PATH ?? '',
        DATABASE_URL: TEST_DATABASE_URL,
        JWT_SECRET: 'too-short',
        PORT: '41999',
        NODE_ENV: 'test',
      },
    });
    expect(result.status).toBe(1);
    expect(result.stderr).toContain('JWT_SECRET must be at least 32 characters');
    // The process must exit before ever listening.
    expect(result.stdout).not.toContain('listening');
  });
});
