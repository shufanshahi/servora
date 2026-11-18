import { AiProviderError, type AiProvider, type GenerateRequest } from './ai.provider';

export interface GeminiOptions {
  apiKey: string;
  model: string;
  timeoutMs: number;
  /** Injectable for tests. Defaults to the global fetch. */
  fetchFn?: typeof fetch;
  baseUrl?: string;
}

const DEFAULT_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';
const MAX_OUTPUT_TOKENS = 1024;

interface GeminiResponse {
  candidates?: { content?: { parts?: { text?: string }[] } }[];
}

export class GeminiProvider implements AiProvider {
  private readonly fetchFn: typeof fetch;
  private readonly baseUrl: string;

  constructor(private readonly options: GeminiOptions) {
    this.fetchFn = options.fetchFn ?? fetch;
    this.baseUrl = options.baseUrl ?? DEFAULT_BASE_URL;
  }

  async generate({ system, messages }: GenerateRequest): Promise<string> {
    let response: Response;
    try {
      response = await this.fetchFn(
        `${this.baseUrl}/models/${encodeURIComponent(this.options.model)}:generateContent`,
        {
          method: 'POST',
          // The key travels in a header (never the URL) so it cannot end up in logs.
          headers: { 'Content-Type': 'application/json', 'x-goog-api-key': this.options.apiKey },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: system }] },
            contents: messages.map((m) => ({
              role: m.role === 'assistant' ? 'model' : 'user',
              parts: [{ text: m.content }],
            })),
            generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS, temperature: 0.4 },
          }),
          signal: AbortSignal.timeout(this.options.timeoutMs),
        },
      );
    } catch (error) {
      const name = (error as { name?: string } | null)?.name;
      throw new AiProviderError(
        name === 'TimeoutError' || name === 'AbortError' ? 'timeout' : 'network',
      );
    }

    if (!response.ok) throw new AiProviderError('http', response.status);

    let body: GeminiResponse;
    try {
      body = (await response.json()) as GeminiResponse;
    } catch {
      throw new AiProviderError('empty');
    }
    const text = (body.candidates?.[0]?.content?.parts ?? [])
      .map((part) => part.text ?? '')
      .join('')
      .trim();
    if (!text) throw new AiProviderError('empty');
    return text;
  }
}
