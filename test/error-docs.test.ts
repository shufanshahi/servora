import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { ERROR_CODES } from '../src/http/errors';

function documentedCodes(): string[] {
  const readme = readFileSync(path.resolve(__dirname, '../README.md'), 'utf8');
  const match = readme.match(/<!-- error-codes:start -->([\s\S]*?)<!-- error-codes:end -->/);
  if (!match?.[1]) throw new Error('README is missing the error-codes table markers');
  return [...match[1].matchAll(/^\|\s*`([A-Z_]+)`\s*\|/gm)].map((m) => m[1] as string);
}

describe('error code documentation', () => {
  it('documents every error code defined in the source, and nothing else', () => {
    expect(documentedCodes().sort()).toEqual(Object.values(ERROR_CODES).sort());
  });
});
