import {
  AiProviderError,
  type AiProvider,
  type GenerateRequest,
} from '../../src/modules/ai/ai.provider';

/** Deterministic provider for tests: records requests, never touches the network. */
export class FakeProvider implements AiProvider {
  readonly calls: GenerateRequest[] = [];
  constructor(private readonly reply: string | (() => never) = 'Fake reply') {}

  async generate(request: GenerateRequest): Promise<string> {
    this.calls.push(request);
    if (typeof this.reply === 'function') this.reply();
    return this.reply as string;
  }
}

/** A provider that always fails the way a real one would. */
export class FailingProvider extends FakeProvider {
  constructor() {
    super(() => {
      throw new AiProviderError('http', 429);
    });
  }
}
