import { tool } from "@opencode-ai/plugin";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

// -------- Configuration --------
const VISION_MODEL = "claude-haiku-4-5";
const ZEN_BASE = "https://opencode.ai/zen/v1";

// -------- Auth --------
function getApiKey(): string | undefined {
  if (process.env.OPENCODE_API_KEY) return process.env.OPENCODE_API_KEY;

  // Fall back to reading the auth store (handles OAuth sign-in via the app)
  try {
    const dataDir =
      process.env.XDG_DATA_HOME || join(homedir(), ".local", "share");
    const raw = readFileSync(join(dataDir, "opencode", "auth.json"), "utf-8");
    const entry = JSON.parse(raw)?.opencode;
    if (entry?.type === "api") return entry.key;
    if (entry?.type === "oauth") return entry.access;
  } catch {}
  return undefined;
}

// -------- Types --------
type MessageWithParts = {
  info: { role: string; id: string };
  parts: Array<{
    type: string;
    mime?: string;
    filename?: string;
    url?: string;
  }>;
};

type ImagePart = { mime: string; filename?: string; url: string };

// -------- Internals --------
function findImages(messages: MessageWithParts[]): ImagePart[] {
  return messages.flatMap((m) =>
    m.parts
      .filter(
        (
          p,
        ): p is {
          type: "file";
          mime: string;
          filename?: string;
          url: string;
        } => p.type === "file" && !!p.mime?.startsWith("image/") && !!p.url,
      )
      .map((p) => ({ mime: p.mime, filename: p.filename, url: p.url })),
  );
}

async function describe(
  image: ImagePart,
  prompt: string,
  apiKey: string,
): Promise<string> {
  const res = await fetch(`${ZEN_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: VISION_MODEL,
      max_tokens: 2048,
      messages: [
        {
          role: "user",
          content: [
            { type: "image_url", image_url: { url: image.url } },
            { type: "text", text: prompt },
          ],
        },
      ],
    }),
  });

  if (!res.ok) return `Zen API error (${res.status}): ${await res.text()}`;
  const data = (await res.json()) as {
    choices: Array<{ message: { content: string } }>;
  };
  return data.choices[0]?.message?.content || "No description returned.";
}

// -------- Tool --------
export default tool({
  description:
    "Describe an image attached to this conversation. Use this tool whenever you encounter an ERROR about unsupported image input instead of telling the user you cannot view images. Sends the image to a vision-capable model and returns a text description.",
  args: {
    filename: tool.schema
      .string()
      .optional()
      .describe(
        "Filename of the image. Omit to describe the most recent image.",
      ),
    question: tool.schema
      .string()
      .optional()
      .describe(
        "Specific question to answer about the image. Omit for a general description.",
      ),
  },
  async execute(args, context) {
    const apiKey = getApiKey();
    if (!apiKey)
      return "No Zen API key found. Set OPENCODE_API_KEY or sign in via the app.";

    const messages = (context as any).messages as
      | MessageWithParts[]
      | undefined;
    if (!messages) return "Cannot access conversation messages.";

    const images = findImages(messages);
    if (!images.length) return "No images found in this conversation.";

    const target = args.filename
      ? (images.find((img) => img.filename === args.filename) ??
        images[images.length - 1])
      : images[images.length - 1];

    const prompt =
      args.question ||
      "Describe this image in detail. Include any text, code, UI elements, diagrams, charts, error messages, or other relevant content visible in the image.";

    return describe(target, prompt, apiKey);
  },
});
