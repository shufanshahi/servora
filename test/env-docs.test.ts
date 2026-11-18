import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { CONFIG_KEYS } from '../src/config';

const root = path.resolve(__dirname, '..');
const readme = readFileSync(path.join(root, 'README.md'), 'utf8');
const example = readFileSync(path.join(root, '.env.example'), 'utf8');

/** Variable names in the first column of the README's Configuration table. */
function documentedVariables(): string[] {
  const section = readme.split('## Configuration')[1]?.split(/\n## /)[0] ?? '';
  return [...section.matchAll(/^\|\s*`([A-Z][A-Z0-9_]*)`\s*\|/gm)].map((m) => m[1] as string);
}

/** Variables actually set (uncommented) in .env.example. */
function exampleVariables(): string[] {
  return [...example.matchAll(/^([A-Z][A-Z0-9_]*)=/gm)].map((m) => m[1] as string);
}

describe('environment variable documentation', () => {
  const documented = documentedVariables();

  it('documents every variable the API reads', () => {
    for (const key of CONFIG_KEYS) {
      expect(documented, `${key} is read by the API but missing from the README table`).toContain(
        key,
      );
    }
  });

  it('documents every variable listed in .env.example', () => {
    for (const key of exampleVariables()) {
      expect(documented, `${key} is in .env.example but missing from the README table`).toContain(
        key,
      );
    }
  });

  it('documents nothing that neither the API nor .env.example knows about', () => {
    const known = new Set([...CONFIG_KEYS, ...exampleVariables()]);
    for (const key of documented) {
      expect(known.has(key), `${key} is documented but does not exist`).toBe(true);
    }
  });

  it('shows no real secret in .env.example', () => {
    const secret = /^JWT_SECRET=(.*)$/m.exec(example)?.[1] ?? '';
    expect(secret.startsWith('dev-only-')).toBe(true);
  });
});
