import type { Config } from '../../config';
import { aiUnavailable } from '../../http/errors';
import type { PublicService } from '../services/services.service';
import { AiProviderError, type AiProvider } from './ai.provider';
import { buildPrompt } from './prompt';

export interface CatalogueSource {
  listActive(): Promise<PublicService[]>;
}

const CATALOGUE_TTL_MS = 60_000;

export type FailureLog = (message: string) => void;

export class AiService {
  private cache: { at: number; services: PublicService[] } | undefined;

  constructor(
    private readonly config: Pick<Config, 'AI_MAX_HISTORY_MESSAGES'>,
    /** Undefined when no key is configured: the feature is disabled, not broken. */
    private readonly provider: AiProvider | undefined,
    private readonly catalogue: CatalogueSource,
    private readonly now: () => number = Date.now,
    private readonly logFailure: FailureLog = (m) => console.error(m),
  ) {}

  async chat(input: {
    message: string;
    history: { role: string; content: string }[];
  }): Promise<string> {
    if (!this.provider) throw aiUnavailable();
    try {
      const prompt = buildPrompt({
        services: await this.activeServices(),
        message: input.message,
        history: input.history,
        maxHistoryMessages: this.config.AI_MAX_HISTORY_MESSAGES,
      });
      return await this.provider.generate(prompt);
    } catch (error) {
      // Log a safe summary only: provider errors carry no key, and nothing else is printed.
      this.logFailure(
        error instanceof AiProviderError
          ? error.message
          : `AI request failed: ${error instanceof Error ? error.name : 'unknown error'}`,
      );
      throw aiUnavailable();
    }
  }

  private async activeServices(): Promise<PublicService[]> {
    const t = this.now();
    if (this.cache && t - this.cache.at < CATALOGUE_TTL_MS) return this.cache.services;
    const services = await this.catalogue.listActive();
    this.cache = { at: t, services };
    return services;
  }
}
