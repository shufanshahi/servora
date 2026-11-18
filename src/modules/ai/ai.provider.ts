export type ChatRole = 'user' | 'assistant';

export interface ChatMessage {
  role: ChatRole;
  content: string;
}

export interface GenerateRequest {
  /** Instructions and grounding data. Always set by the server, never by the client. */
  system: string;
  /** Conversation so far, ending with the user's newest message. */
  messages: ChatMessage[];
}

/** A text-generation backend. Adding another provider means adding one class. */
export interface AiProvider {
  generate(request: GenerateRequest): Promise<string>;
}

export type AiFailureKind = 'timeout' | 'network' | 'http' | 'empty';

/** Typed provider failure. Its message never contains credentials or provider payloads. */
export class AiProviderError extends Error {
  constructor(
    readonly kind: AiFailureKind,
    readonly status?: number,
  ) {
    super(
      status ? `AI provider failure: ${kind} (status ${status})` : `AI provider failure: ${kind}`,
    );
    this.name = 'AiProviderError';
  }
}
