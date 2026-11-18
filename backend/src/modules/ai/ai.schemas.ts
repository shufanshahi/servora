import { z } from 'zod';

/** Body of POST /ai/chat. Only user and assistant roles exist, so "system" cannot be injected. */
export function chatBody(maxMessageChars: number) {
  return z.object({
    message: z
      .string()
      .trim()
      .min(1, 'Message must not be empty')
      .max(maxMessageChars, `Message must be at most ${maxMessageChars} characters`),
    history: z
      .array(
        z.object({
          role: z.enum(['user', 'assistant']),
          content: z.string(),
        }),
      )
      .max(200)
      .default([]),
  });
}

export type ChatInput = z.infer<ReturnType<typeof chatBody>>;
