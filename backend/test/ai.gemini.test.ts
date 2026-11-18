import { describe, expect, it } from 'vitest';
import { AiProviderError } from '../src/modules/ai/ai.provider';
import { GeminiProvider } from '../src/modules/ai/gemini.provider';

const KEY = 'SECRET-KEY-DO-NOT-LEAK';
const make = (fetchFn: typeof fetch) =>
  new GeminiProvider({ apiKey: KEY, model: 'test-model', timeoutMs: 1000, fetchFn });
const json = (body: unknown, status = 200) =>
  Promise.resolve(new Response(JSON.stringify(body), { status }));

async function failure(provider: GeminiProvider): Promise<AiProviderError> {
  try {
    await provider.generate({ system: 's', messages: [{ role: 'user', content: 'hi' }] });
  } catch (error) {
    return error as AiProviderError;
  }
  throw new Error('expected a failure');
}

describe('GeminiProvider', () => {
  it('sends the key in a header (not the URL) and maps roles and system text', async () => {
    let url = '';
    let init: RequestInit = {};
    const provider = make((u, i) => {
      url = String(u);
      init = i ?? {};
      return json({
        candidates: [{ content: { parts: [{ text: 'Hello ' }, { text: 'there' }] } }],
      });
    });
    const reply = await provider.generate({
      system: 'SYS',
      messages: [
        { role: 'user', content: 'a' },
        { role: 'assistant', content: 'b' },
        { role: 'user', content: 'c' },
      ],
    });
    expect(reply).toBe('Hello there');
    expect(url).toContain('/models/test-model:generateContent');
    expect(url).not.toContain(KEY);
    expect((init.headers as Record<string, string>)['x-goog-api-key']).toBe(KEY);
    const body = JSON.parse(init.body as string);
    expect(body.systemInstruction.parts[0].text).toBe('SYS');
    expect(body.contents.map((c: { role: string }) => c.role)).toEqual(['user', 'model', 'user']);
  });

  it('maps an HTTP error to a typed failure without the key', async () => {
    const err = await failure(make(() => json({ error: { message: `bad ${KEY}` } }, 429)));
    expect(err).toBeInstanceOf(AiProviderError);
    expect(err.kind).toBe('http');
    expect(err.status).toBe(429);
    expect(err.message).not.toContain(KEY);
  });

  it('maps a timeout to a typed failure', async () => {
    const err = await failure(
      make(() => Promise.reject(new DOMException('timed out', 'TimeoutError'))),
    );
    expect(err.kind).toBe('timeout');
    expect(err.message).not.toContain(KEY);
  });

  it('maps network errors (even ones mentioning the key) without leaking it', async () => {
    const err = await failure(make(() => Promise.reject(new Error(`boom ${KEY}`))));
    expect(err.kind).toBe('network');
    expect(err.message).not.toContain(KEY);
  });

  it('maps an empty or blocked answer to a typed failure', async () => {
    expect((await failure(make(() => json({ candidates: [] })))).kind).toBe('empty');
    expect((await failure(make(() => Promise.resolve(new Response('not json'))))).kind).toBe(
      'empty',
    );
  });
});
