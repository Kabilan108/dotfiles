import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
	truncateHead,
	withFileMutationQueue,
} from "@mariozechner/pi-coding-agent";
import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";

const EXA_API_BASE = "https://api.exa.ai";
const EXA_API_KEY_ENV = "EXA_API_KEY";
const DEFAULT_HIGHLIGHT_CHARACTERS = 3000;
const DEFAULT_TEXT_CHARACTERS = 12000;
const SEARCH_TYPES = ["auto", "fast", "instant", "deep-lite", "deep", "deep-reasoning"] as const;
const SEARCH_CONTENT_MODES = ["highlights", "text", "both"] as const;
const EXTRACT_CONTENT_MODES = ["highlights", "text", "both", "summary"] as const;
const CODE_FOCUS = ["docs", "source", "mixed"] as const;

interface ExaSearchResult {
	url: string;
	title?: string;
	author?: string;
	publishedDate?: string;
	highlights?: string[];
	text?: string;
	summary?: unknown;
	score?: number;
}

interface ExaSearchResponse {
	results?: ExaSearchResult[];
	requestId?: string;
	output?: {
		content?: unknown;
	};
}

interface FinalizedOutput {
	text: string;
	truncated: boolean;
	fullOutputPath?: string;
}

const WebSearchParams = Type.Object({
	query: Type.String({ description: "What to search for on the web" }),
	searchType: Type.Optional(StringEnum(SEARCH_TYPES, { description: "Search mode. auto is a strong default." })),
	numResults: Type.Optional(
		Type.Integer({ minimum: 1, maximum: 10, description: "How many results to return (default 5)" }),
	),
	contentMode: Type.Optional(
		StringEnum(SEARCH_CONTENT_MODES, {
			description: "Return highlights, full text, or both. Default is highlights.",
		}),
	),
	highlightMaxCharacters: Type.Optional(
		Type.Integer({ minimum: 500, maximum: 12000, description: "Max highlight characters per result" }),
	),
	textMaxCharacters: Type.Optional(
		Type.Integer({ minimum: 1000, maximum: 20000, description: "Max full-text characters per result" }),
	),
	includeDomains: Type.Optional(
		Type.Array(Type.String(), { description: "Restrict results to these domains" }),
	),
	excludeDomains: Type.Optional(
		Type.Array(Type.String(), { description: "Exclude these domains" }),
	),
	freshnessHours: Type.Optional(
		Type.Integer({ minimum: -1, description: "Use 0 for always livecrawl, -1 for cache-only" }),
	),
	category: Type.Optional(Type.String({ description: "Optional Exa category like news, company, people" })),
});

const CodeSearchParams = Type.Object({
	query: Type.String({ description: "What docs or source code to find" }),
	focus: Type.Optional(
		StringEnum(CODE_FOCUS, {
			description: "docs = docs/API reference, source = GitHub/source code, mixed = both",
		}),
	),
	searchType: Type.Optional(StringEnum(SEARCH_TYPES, { description: "Search mode. auto is a strong default." })),
	numResults: Type.Optional(
		Type.Integer({ minimum: 1, maximum: 10, description: "How many results to return (default 6)" }),
	),
	contentMode: Type.Optional(
		StringEnum(SEARCH_CONTENT_MODES, {
			description: "Return highlights, full text, or both. Default is highlights.",
		}),
	),
	highlightMaxCharacters: Type.Optional(
		Type.Integer({ minimum: 500, maximum: 12000, description: "Max highlight characters per result" }),
	),
	textMaxCharacters: Type.Optional(
		Type.Integer({ minimum: 1000, maximum: 20000, description: "Max full-text characters per result" }),
	),
	domains: Type.Optional(
		Type.Array(Type.String(), { description: "Additional domains to prioritize/include" }),
	),
	excludeDomains: Type.Optional(
		Type.Array(Type.String(), { description: "Exclude these domains" }),
	),
	freshnessHours: Type.Optional(
		Type.Integer({ minimum: -1, description: "Use 0 for always livecrawl, -1 for cache-only" }),
	),
});

const ReadWebPagesParams = Type.Object({
	urls: Type.Array(Type.String(), {
		minItems: 1,
		maxItems: 10,
		description: "URLs to extract clean web content from",
	}),
	contentMode: Type.Optional(
		StringEnum(EXTRACT_CONTENT_MODES, {
			description: "highlights, text, both, or summary. Default is highlights.",
		}),
	),
	query: Type.Optional(
		Type.String({ description: "Guide highlights or summaries toward a specific question" }),
	),
	highlightMaxCharacters: Type.Optional(
		Type.Integer({ minimum: 500, maximum: 12000, description: "Max highlight characters per URL" }),
	),
	textMaxCharacters: Type.Optional(
		Type.Integer({ minimum: 1000, maximum: 40000, description: "Max full-text characters per URL" }),
	),
	freshnessHours: Type.Optional(
		Type.Integer({ minimum: -1, description: "Use 0 for always livecrawl, -1 for cache-only" }),
	),
	subpages: Type.Optional(
		Type.Integer({ minimum: 0, maximum: 10, description: "Also crawl linked subpages per URL" }),
	),
	subpageTarget: Type.Optional(
		Type.Array(Type.String(), { description: "Keywords to prioritize when selecting subpages" }),
	),
});

function getApiKey(): string {
	const apiKey = process.env[EXA_API_KEY_ENV]?.trim();
	if (!apiKey) {
		throw new Error(
			`Missing ${EXA_API_KEY_ENV} in Pi's environment. Export it before using the Exa search tools.`,
		);
	}
	return apiKey;
}

function uniqueDomains(values?: string[]): string[] | undefined {
	if (!values?.length) return undefined;
	const normalized = values
		.map((value) => value.trim())
		.filter(Boolean)
		.map((value) => value.replace(/^https?:\/\//, "").replace(/\/$/, ""));
	return normalized.length > 0 ? Array.from(new Set(normalized)) : undefined;
}

function uniqueValues(values?: string[]): string[] | undefined {
	if (!values?.length) return undefined;
	const normalized = values.map((value) => value.trim()).filter(Boolean);
	return normalized.length > 0 ? Array.from(new Set(normalized)) : undefined;
}

function uniqueUrls(values?: string[]): string[] | undefined {
	return uniqueValues(values);
}

function compactWhitespace(text: string): string {
	return text.replace(/\s+/g, " ").trim();
}

function previewText(text: string, maxCharacters: number): string {
	const compact = compactWhitespace(text);
	if (compact.length <= maxCharacters) return compact;
	return `${compact.slice(0, Math.max(0, maxCharacters - 1)).trimEnd()}…`;
}

function formatStructuredSummary(summary: unknown): string | undefined {
	if (summary === undefined || summary === null) return undefined;
	if (typeof summary === "string") return compactWhitespace(summary);
	try {
		return JSON.stringify(summary, null, 2);
	} catch {
		return String(summary);
	}
}

function buildSearchContents(
	contentMode: (typeof SEARCH_CONTENT_MODES)[number] = "highlights",
	highlightMaxCharacters?: number,
	textMaxCharacters?: number,
) {
	const contents: Record<string, unknown> = {};
	if (contentMode === "highlights" || contentMode === "both") {
		contents.highlights = {
			maxCharacters: highlightMaxCharacters ?? DEFAULT_HIGHLIGHT_CHARACTERS,
		};
	}
	if (contentMode === "text" || contentMode === "both") {
		contents.text = {
			maxCharacters: textMaxCharacters ?? DEFAULT_TEXT_CHARACTERS,
		};
	}
	return contents;
}

function buildContentsRequest(params: {
	contentMode: (typeof EXTRACT_CONTENT_MODES)[number];
	query?: string;
	highlightMaxCharacters?: number;
	textMaxCharacters?: number;
}) {
	const request: Record<string, unknown> = {};
	if (params.contentMode === "highlights" || params.contentMode === "both") {
		request.highlights = {
			maxCharacters: params.highlightMaxCharacters ?? DEFAULT_HIGHLIGHT_CHARACTERS,
			...(params.query ? { query: params.query } : {}),
		};
	}
	if (params.contentMode === "text" || params.contentMode === "both") {
		request.text = {
			maxCharacters: params.textMaxCharacters ?? DEFAULT_TEXT_CHARACTERS,
		};
	}
	if (params.contentMode === "summary") {
		request.summary = params.query ? { query: params.query } : true;
	}
	return request;
}

function formatSearchResults(
	label: string,
	query: string,
	response: ExaSearchResponse,
	contentMode: (typeof SEARCH_CONTENT_MODES)[number],
): string {
	const lines: string[] = [];
	const results = response.results ?? [];
	lines.push(`${label} results for: ${query}`);
	lines.push(`Returned ${results.length} result(s).`);
	if (response.requestId) lines.push(`Request ID: ${response.requestId}`);

	const synthesized = formatStructuredSummary(response.output?.content);
	if (synthesized) {
		lines.push("");
		lines.push("Synthesized output:");
		lines.push(synthesized);
	}

	if (results.length === 0) {
		lines.push("");
		lines.push("No results found.");
		return lines.join("\n");
	}

	for (const [index, result] of results.entries()) {
		lines.push("");
		lines.push(`${index + 1}. ${result.title?.trim() || "(untitled)"}`);
		lines.push(`URL: ${result.url}`);
		if (typeof result.score === "number") lines.push(`Score: ${result.score.toFixed(4)}`);
		if (result.author) lines.push(`Author: ${result.author}`);
		if (result.publishedDate) lines.push(`Published: ${result.publishedDate}`);

		if (Array.isArray(result.highlights) && result.highlights.length > 0) {
			lines.push("Highlights:");
			for (const highlight of result.highlights.slice(0, 4)) {
				lines.push(`- ${previewText(highlight, 500)}`);
			}
		}

		if ((contentMode === "text" || contentMode === "both") && result.text?.trim()) {
			lines.push("Text:");
			lines.push(previewText(result.text, contentMode === "text" ? 2200 : 1200));
		}
	}

	return lines.join("\n");
}

function formatContentsResults(
	urls: string[],
	response: ExaSearchResponse,
	contentMode: (typeof EXTRACT_CONTENT_MODES)[number],
): string {
	const lines: string[] = [];
	const results = response.results ?? [];
	lines.push(`Extracted ${results.length} page(s) from ${urls.length} requested URL(s).`);
	if (response.requestId) lines.push(`Request ID: ${response.requestId}`);

	if (results.length === 0) {
		lines.push("");
		lines.push("No page contents were returned.");
		return lines.join("\n");
	}

	for (const [index, result] of results.entries()) {
		lines.push("");
		lines.push(`${index + 1}. ${result.title?.trim() || result.url || urls[index] || "(untitled)"}`);
		lines.push(`URL: ${result.url || urls[index]}`);

		const summary = formatStructuredSummary(result.summary);
		if (summary) {
			lines.push("Summary:");
			lines.push(summary);
		}

		if (Array.isArray(result.highlights) && result.highlights.length > 0) {
			lines.push("Highlights:");
			for (const highlight of result.highlights.slice(0, 5)) {
				lines.push(`- ${previewText(highlight, 500)}`);
			}
		}

		if ((contentMode === "text" || contentMode === "both") && result.text?.trim()) {
			lines.push("Text:");
			lines.push(previewText(result.text, contentMode === "text" ? 2600 : 1400));
		}
	}

	return lines.join("\n");
}

async function finalizeOutput(prefix: string, text: string): Promise<FinalizedOutput> {
	const truncation = truncateHead(text, {
		maxLines: DEFAULT_MAX_LINES,
		maxBytes: DEFAULT_MAX_BYTES,
	});

	if (!truncation.truncated) {
		return { text: truncation.content, truncated: false };
	}

	const tempDir = await mkdtemp(join(tmpdir(), `${prefix}-`));
	const tempFile = join(tempDir, "output.txt");
	await withFileMutationQueue(tempFile, async () => {
		await writeFile(tempFile, text, "utf8");
	});

	let resultText = truncation.content;
	resultText += `\n\n[Output truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines`;
	resultText += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}).`;
	resultText += ` Full output saved to: ${tempFile}]`;

	return {
		text: resultText,
		truncated: true,
		fullOutputPath: tempFile,
	};
}

async function exaPost(endpoint: string, body: Record<string, unknown>, signal?: AbortSignal): Promise<ExaSearchResponse> {
	const response = await fetch(`${EXA_API_BASE}${endpoint}`, {
		method: "POST",
		headers: {
			"content-type": "application/json",
			"x-api-key": getApiKey(),
		},
		body: JSON.stringify(body),
		signal,
	});

	if (!response.ok) {
		const errorText = await response.text();
		throw new Error(`Exa API ${response.status}: ${errorText || response.statusText}`);
	}

	return (await response.json()) as ExaSearchResponse;
}

function buildCodeSearchQuery(query: string, focus: (typeof CODE_FOCUS)[number] = "mixed"): string {
	switch (focus) {
		case "docs":
			return `${query}\nFocus on official documentation, API references, guides, and examples.`;
		case "source":
			return `${query}\nFocus on source code, repositories, implementation examples, and GitHub results.`;
		default:
			return query;
	}
}

function defaultDomainsForCodeFocus(focus: (typeof CODE_FOCUS)[number] = "mixed"): string[] | undefined {
	if (focus === "source") return ["github.com"];
	return undefined;
}

export default function exaSearchExtension(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		if (!process.env[EXA_API_KEY_ENV]?.trim()) {
			ctx.ui.notify(
				`exa-search: ${EXA_API_KEY_ENV} is not set. The Exa tools will fail until Pi is started with that environment variable.`,
				"warning",
			);
		}
	});

	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description: `Search the web with Exa. Returns ranked results with highlights or full text. Output is truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(DEFAULT_MAX_BYTES)}.`,
		promptSnippet: "Search the web for facts, docs, announcements, and current information using Exa.",
		promptGuidelines: [
			"Use web_search instead of ad-hoc shell/curl search when the user needs web results.",
			"Prefer highlights for fast agent workflows; use text only when more context is genuinely needed.",
		],
		parameters: WebSearchParams,
		async execute(_toolCallId, params, signal) {
			const contentMode = params.contentMode ?? "highlights";
			const body: Record<string, unknown> = {
				query: params.query,
				type: params.searchType ?? "auto",
				numResults: params.numResults ?? 5,
				contents: buildSearchContents(contentMode, params.highlightMaxCharacters, params.textMaxCharacters),
			};
			const includeDomains = uniqueDomains(params.includeDomains);
			const excludeDomains = uniqueDomains(params.excludeDomains);
			if (includeDomains) body.includeDomains = includeDomains;
			if (excludeDomains) body.excludeDomains = excludeDomains;
			if (params.freshnessHours !== undefined) body.maxAgeHours = params.freshnessHours;
			if (params.category) body.category = params.category;

			const response = await exaPost("/search", body, signal);
			const rawText = formatSearchResults("Web search", params.query, response, contentMode);
			const finalized = await finalizeOutput("pi-exa-web-search", rawText);

			return {
				content: [{ type: "text", text: finalized.text }],
				details: {
					query: params.query,
					searchType: params.searchType ?? "auto",
					contentMode,
					resultCount: response.results?.length ?? 0,
					requestId: response.requestId,
					truncated: finalized.truncated,
					fullOutputPath: finalized.fullOutputPath,
				},
			};
		},
	});

	pi.registerTool({
		name: "code_search",
		label: "Code Search",
		description: `Search for documentation and source code with Exa. Great for API docs, GitHub repos, implementation examples, and framework references. Output is truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(DEFAULT_MAX_BYTES)}.`,
		promptSnippet: "Search for documentation, API references, and source code using Exa.",
		promptGuidelines: [
			"Use code_search for API docs, GitHub/source-code discovery, implementation examples, and library references.",
			"Prefer focus=docs for official documentation and focus=source for repository/code hunting.",
		],
		parameters: CodeSearchParams,
		async execute(_toolCallId, params, signal) {
			const focus = params.focus ?? "mixed";
			const contentMode = params.contentMode ?? "highlights";
			const includeDomains = uniqueDomains([
				...(defaultDomainsForCodeFocus(focus) ?? []),
				...(params.domains ?? []),
			]);
			const excludeDomains = uniqueDomains(params.excludeDomains);

			const body: Record<string, unknown> = {
				query: buildCodeSearchQuery(params.query, focus),
				type: params.searchType ?? "auto",
				numResults: params.numResults ?? 6,
				contents: buildSearchContents(contentMode, params.highlightMaxCharacters, params.textMaxCharacters),
				systemPrompt:
					"Prefer official docs, authoritative source code, implementation examples, and avoid duplicate domains when possible.",
			};
			if (includeDomains) body.includeDomains = includeDomains;
			if (excludeDomains) body.excludeDomains = excludeDomains;
			if (params.freshnessHours !== undefined) body.maxAgeHours = params.freshnessHours;

			const response = await exaPost("/search", body, signal);
			const rawText = formatSearchResults("Code search", params.query, response, contentMode);
			const finalized = await finalizeOutput("pi-exa-code-search", rawText);

			return {
				content: [{ type: "text", text: finalized.text }],
				details: {
					query: params.query,
					focus,
					searchType: params.searchType ?? "auto",
					contentMode,
					resultCount: response.results?.length ?? 0,
					requestId: response.requestId,
					truncated: finalized.truncated,
					fullOutputPath: finalized.fullOutputPath,
				},
			};
		},
	});

	pi.registerTool({
		name: "read_web_pages",
		label: "Read Web Pages",
		description: `Extract clean web page contents with Exa's Contents API. Useful after web_search/code_search when you want to expand promising URLs. Output is truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(DEFAULT_MAX_BYTES)}.`,
		promptSnippet: "Extract clean highlights, text, or summaries from web pages using Exa.",
		promptGuidelines: [
			"Use read_web_pages after finding promising URLs with web_search or code_search.",
			"Prefer highlights first; request text when you need more context from a small number of URLs.",
		],
		parameters: ReadWebPagesParams,
		async execute(_toolCallId, params, signal) {
			const urls = uniqueUrls(params.urls);
			if (!urls || urls.length === 0) {
				throw new Error("read_web_pages requires at least one URL.");
			}

			const contentMode = params.contentMode ?? "highlights";
			const body: Record<string, unknown> = {
				urls,
				...buildContentsRequest({
					contentMode,
					query: params.query,
					highlightMaxCharacters: params.highlightMaxCharacters,
					textMaxCharacters: params.textMaxCharacters,
				}),
			};
			if (params.freshnessHours !== undefined) body.maxAgeHours = params.freshnessHours;
			if (params.subpages !== undefined) body.subpages = params.subpages;
			const subpageTarget = uniqueValues(params.subpageTarget);
			if (subpageTarget) body.subpageTarget = subpageTarget;

			const response = await exaPost("/contents", body, signal);
			const rawText = formatContentsResults(urls, response, contentMode);
			const finalized = await finalizeOutput("pi-exa-read-web-pages", rawText);

			return {
				content: [{ type: "text", text: finalized.text }],
				details: {
					urls,
					contentMode,
					query: params.query,
					resultCount: response.results?.length ?? 0,
					requestId: response.requestId,
					truncated: finalized.truncated,
					fullOutputPath: finalized.fullOutputPath,
				},
			};
		},
	});
}
