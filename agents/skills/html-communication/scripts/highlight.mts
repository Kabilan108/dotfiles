// Syntax-highlights <pre><code> blocks in HTML artifacts, in place, with no runtime JavaScript.
// Usage: node highlight.mts page.html [more.html ...] [--root <repo>]

import { readFileSync, writeFileSync } from "node:fs";
import { resolve, sep } from "node:path";
import { createHighlighter, type Highlighter, type ThemedToken } from "./vendor/shiki.mjs";

const THEMES = { light: "catppuccin-latte", dark: "catppuccin-mocha" } as const;
const PLAIN = new Set(["text", "plaintext", "plain", "txt", "tree", "none", "output", "console-output"]);
const BLOCK = /<pre\b([^>]*)>(\s*)<code\b([^>]*)>([\s\S]*?)<\/code>(\s*)<\/pre>/g;
const STYLE_TAG = /<style data-highlight>[\s\S]*?<\/style>\s*/;
const META_LINE = /^(diff |index |--- |\+\+\+ |new file|deleted file|similarity |rename |old mode|new mode|Binary |\\ )/;

const EXTENSIONS: Record<string, string> = {
  ts: "typescript", mts: "typescript", cts: "typescript", tsx: "tsx",
  js: "javascript", mjs: "javascript", cjs: "javascript", jsx: "jsx",
  json: "json", jsonc: "jsonc", py: "python", go: "go", rs: "rust", nix: "nix", lua: "lua",
  sh: "shellscript", bash: "shellscript", zsh: "shellscript", envrc: "shellscript", fish: "fish",
  toml: "toml", yml: "yaml", yaml: "yaml", sql: "sql", html: "html", htm: "html",
  css: "css", scss: "scss", md: "markdown", c: "c", h: "c", java: "java", kt: "kotlin",
  swift: "swift", rb: "ruby", graphql: "graphql", gql: "graphql", proto: "proto", ini: "ini",
  kdl: "kdl", xml: "xml", svg: "xml", qml: "qml", r: "r", mk: "make", cmake: "cmake",
  hcl: "hcl", tf: "hcl", zig: "zig", diff: "diff", patch: "diff",
};
const INTERPRETERS: Record<string, string> = {
  python: "python", python3: "python", bash: "shellscript", sh: "shellscript", zsh: "shellscript",
  fish: "fish", node: "javascript", bun: "typescript", deno: "typescript", lua: "lua", ruby: "ruby",
};
const FILENAMES: Record<string, string> = {
  dockerfile: "dockerfile", makefile: "make", "cmakelists.txt": "cmake", ".envrc": "shellscript",
};

const CSS = `pre.hl{background:var(--shiki-light-bg);color:var(--shiki-light);padding:12px 14px;border-radius:8px;overflow-x:auto;tab-size:4}
pre.hl span{color:var(--shiki-light)}
pre.hl .line.add,pre.hl .line.del,pre.hl .line.hunk,pre.hl .line.meta,pre.hl .line.focus{display:inline-block;min-width:100%}
pre.hl .line.focus{box-sizing:border-box;min-width:calc(100% + 8px);border-left:3px solid #df8e1d;margin-left:-8px;padding-left:5px}pre.hl .line.focus:not(.add):not(.del){background:rgba(223,142,29,.16)}
pre.hl .line.add{background:rgba(64,160,43,.16)}pre.hl .line.del{background:rgba(210,15,57,.13)}
pre.hl .line.add>.mark{color:#40a02b}pre.hl .line.del>.mark{color:#d20f39}
pre.hl .line.hunk,pre.hl .line.hunk span{color:#1e66f5}pre.hl .line.meta,pre.hl .line.meta span{color:#8c8fa1}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]) pre.hl{background:var(--shiki-dark-bg);color:var(--shiki-dark)}:root:not([data-theme=light]) pre.hl span{color:var(--shiki-dark)}:root:not([data-theme=light]) pre.hl .line.hunk,:root:not([data-theme=light]) pre.hl .line.hunk span{color:#89b4fa}:root:not([data-theme=light]) pre.hl .line.meta,:root:not([data-theme=light]) pre.hl .line.meta span{color:#7f849c}:root:not([data-theme=light]) pre.hl .line.add>.mark{color:#a6e3a1}:root:not([data-theme=light]) pre.hl .line.del>.mark{color:#f38ba8}:root:not([data-theme=light]) pre.hl .line.focus{border-left-color:#f9e2af}:root:not([data-theme=light]) pre.hl .line.focus:not(.add):not(.del){background:rgba(249,226,175,.18)}}
:root[data-theme=dark] pre.hl{background:var(--shiki-dark-bg);color:var(--shiki-dark)}:root[data-theme=dark] pre.hl span{color:var(--shiki-dark)}:root[data-theme=dark] pre.hl .line.hunk,:root[data-theme=dark] pre.hl .line.hunk span{color:#89b4fa}:root[data-theme=dark] pre.hl .line.meta,:root[data-theme=dark] pre.hl .line.meta span{color:#7f849c}:root[data-theme=dark] pre.hl .line.add>.mark{color:#a6e3a1}:root[data-theme=dark] pre.hl .line.del>.mark{color:#f38ba8}:root[data-theme=dark] pre.hl .line.focus{border-left-color:#f9e2af}:root[data-theme=dark] pre.hl .line.focus:not(.add):not(.del){background:rgba(249,226,175,.18)}`;

interface Stats {
  highlighted: number;
  diffs: number;
  plain: number;
  skipped: string[];
  notes: string[];
}

function escapeHtml(text: string): string {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function decodeHtml(text: string): string {
  return text
    .replace(/<[^>]*>/g, "")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex: string) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec: string) => String.fromCodePoint(Number(dec)))
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&");
}

function attr(attrs: string, name: string): string | undefined {
  const match = attrs.match(new RegExp(`\\s${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, "i"));
  return match ? (match[1] ?? match[2] ?? match[3]) : undefined;
}

function setAttr(attrs: string, name: string, value: string | null): string {
  const pattern = new RegExp(`\\s${name}(\\s*=\\s*(?:"[^"]*"|'[^']*'|[^\\s>]+))?`, "gi");
  const stripped = attrs.replace(pattern, "");
  return value === null ? stripped : `${stripped} ${name}="${value}"`;
}

function languageFromClass(attrs: string): string | undefined {
  const match = (attr(attrs, "class") ?? "").match(/(?:^|\s)lang(?:uage)?-([\w+#-]+)/i);
  return match?.[1].toLowerCase();
}

function languageFromPath(path: string): string | undefined {
  const name = path.split("/").pop()?.toLowerCase() ?? "";
  return FILENAMES[name] ?? EXTENSIONS[name.split(".").pop() ?? ""];
}

function languageFromShebang(root: string | undefined, path: string): string | undefined {
  if (!root) return undefined;
  const base = resolve(root);
  const file = resolve(base, path);
  if (!file.startsWith(base + sep)) return undefined;
  let first: string;
  try {
    first = readFileSync(file, "utf8").split("\n", 1)[0];
  } catch {
    return undefined;
  }
  const match = first.match(/^#!\s*(\S+)(.*)$/);
  if (!match) return undefined;
  const command = match[1].split("/").pop() ?? "";
  const program = command === "env" ? match[2].trim().split(/\s+/).find((word) => !word.startsWith("-")) : command;
  return program ? (INTERPRETERS[program] ?? INTERPRETERS[program.replace(/[\d.]+$/, "")]) : undefined;
}

function enclosingSource(html: string, index: number): { path: string; start: number } | undefined {
  const before = html.slice(0, index);
  const open = before.lastIndexOf("<figure");
  if (open < 0 || before.lastIndexOf("</figure>") > open) return undefined;
  const tag = before.slice(open, before.indexOf(">", open) + 1);
  const spec = attr(tag, "data-source");
  if (!spec) return undefined;
  const [path, range = ""] = spec.split(":");
  return { path, start: Number.parseInt(range, 10) || 1 };
}

function focusLines(spec: string | undefined, firstNumber: number, count: number): { lines: Set<number>; outside: string[] } {
  const lines = new Set<number>();
  const outside: string[] = [];
  for (const part of (spec ?? "").split(",").map((s) => s.trim()).filter(Boolean)) {
    const [from, to = from] = part.split("-").map((n) => Number.parseInt(n, 10));
    if (!Number.isFinite(from) || !Number.isFinite(to) || to < from) {
      outside.push(part);
      continue;
    }
    for (let n = from; n <= to; n++) {
      const index = n - firstNumber;
      if (index >= 0 && index < count) lines.add(index);
      else outside.push(String(n));
    }
  }
  return { lines, outside };
}

function markFocus(body: string, lines: Set<number>): string {
  if (!lines.size) return body;
  return body
    .split("\n")
    .map((line, i) => (lines.has(i) ? line.replace('<span class="line', '<span class="line focus') : line))
    .join("\n");
}

function diffTarget(code: string): string | undefined {
  const header = code.match(/^\+\+\+ (?:b\/)?(\S+)/m) ?? code.match(/^--- (?:a\/)?(\S+)/m);
  return header && header[1] !== "/dev/null" ? languageFromPath(header[1]) : undefined;
}

function tokenSpans(tokens: ThemedToken[]): string {
  return tokens
    .map((token) => {
      const style = Object.entries(token.htmlStyle ?? {})
        .map(([key, value]) => `${key}:${value}`)
        .join(";");
      return style ? `<span style="${style}">${escapeHtml(token.content)}</span>` : escapeHtml(token.content);
    })
    .join("");
}

function tokenize(highlighter: Highlighter, code: string, lang: string): { lines: ThemedToken[][]; rootStyle: string } {
  const result = highlighter.codeToTokens(code, { lang, themes: THEMES, defaultColor: false });
  return { lines: result.tokens, rootStyle: result.rootStyle ?? "" };
}

function renderCode(highlighter: Highlighter, code: string, lang: string): { body: string; rootStyle: string } {
  const { lines, rootStyle } = tokenize(highlighter, code, lang);
  return { body: lines.map((line) => `<span class="line">${tokenSpans(line)}</span>`).join("\n"), rootStyle };
}

function renderDiff(highlighter: Highlighter, code: string, lang: string): { body: string; rootStyle: string } {
  const lines = code.split("\n");
  const out: string[] = new Array(lines.length);
  let rootStyle = tokenize(highlighter, "", lang).rootStyle;
  let hunk: number[] = [];

  const flush = (): void => {
    if (!hunk.length) return;
    const oldSide: string[] = [];
    const newSide: string[] = [];
    for (const i of hunk) {
      const mark = lines[i][0] ?? " ";
      const body = lines[i].slice(1);
      if (mark !== "+") oldSide.push(body);
      if (mark !== "-") newSide.push(body);
    }
    const oldTokens = tokenize(highlighter, oldSide.join("\n"), lang);
    const newTokens = tokenize(highlighter, newSide.join("\n"), lang);
    rootStyle = newTokens.rootStyle || rootStyle;
    let oldIndex = 0;
    let newIndex = 0;
    for (const i of hunk) {
      const mark = lines[i][0] ?? "";
      const kind = mark === "+" ? "add" : mark === "-" ? "del" : "ctx";
      const tokens = kind === "del" ? oldTokens.lines[oldIndex] : newTokens.lines[newIndex];
      if (kind !== "add") oldIndex++;
      if (kind !== "del") newIndex++;
      out[i] = `<span class="line ${kind}"><span class="mark">${escapeHtml(mark)}</span>${tokenSpans(tokens ?? [])}</span>`;
    }
    hunk = [];
  };

  lines.forEach((line, i) => {
    if (line.startsWith("@@")) {
      flush();
      out[i] = `<span class="line hunk">${escapeHtml(line)}</span>`;
    } else if (META_LINE.test(line)) {
      flush();
      out[i] = `<span class="line meta">${escapeHtml(line)}</span>`;
    } else {
      hunk.push(i);
    }
  });
  flush();
  return { body: out.join("\n"), rootStyle };
}

function highlightHtml(highlighter: Highlighter, html: string, stats: Stats, root: string | undefined): string {
  const known = new Set(highlighter.getLoadedLanguages());
  const rewritten = html.replace(BLOCK, (whole, preAttrs: string, gapA: string, codeAttrs: string, inner: string, gapB: string, offset: number) => {
    const declared = languageFromClass(codeAttrs) ?? languageFromClass(preAttrs) ?? attr(codeAttrs, "data-lang") ?? attr(preAttrs, "data-lang");
    const source = enclosingSource(html, offset);
    const sourcePath = source?.path;
    const lang = declared ?? (sourcePath ? (languageFromPath(sourcePath) ?? languageFromShebang(root, sourcePath)) : undefined);
    if (!lang) {
      const hint = sourcePath && !root ? `; pass --root to read the shebang of ${sourcePath}` : "";
      stats.skipped.push(`line ${html.slice(0, offset).split("\n").length}: no language (add class="language-…", or language-text for plain text${hint})`);
      return whole;
    }
    if (PLAIN.has(lang)) {
      stats.plain++;
      return whole;
    }
    let code = decodeHtml(inner);
    if (code.endsWith("\n")) code = code.slice(0, -1);
    const isDiff = lang === "diff" || lang === "patch";
    const target = isDiff ? (attr(codeAttrs, "data-lang") ?? attr(preAttrs, "data-lang") ?? diffTarget(code) ?? "diff") : lang;
    if (!known.has(target)) {
      stats.skipped.push(`line ${html.slice(0, offset).split("\n").length}: language "${target}" is not bundled`);
      return whole;
    }
    const rendered = isDiff && target !== "diff" ? renderDiff(highlighter, code, target) : renderCode(highlighter, code, target);
    const focusSpec = attr(codeAttrs, "data-hl") ?? attr(preAttrs, "data-hl");
    const focus = focusLines(focusSpec, isDiff ? 1 : (source?.start ?? 1), code.split("\n").length);
    if (focus.outside.length) {
      stats.notes.push(`line ${html.slice(0, offset).split("\n").length}: data-hl ${focus.outside.join(", ")} is outside the block (excerpts use file line numbers)`);
    }
    const body = markFocus(rendered.body, focus.lines);
    const rootStyle = rendered.rootStyle;
    if (isDiff) stats.diffs++;
    else stats.highlighted++;

    const classes = new Set((attr(preAttrs, "class") ?? "").split(/\s+/).filter(Boolean));
    classes.add("hl");
    const ownStyle = (attr(preAttrs, "style") ?? "")
      .split(";")
      .filter((rule) => rule.trim() && !rule.trim().startsWith("--shiki-"))
      .join(";");
    let attrs = setAttr(preAttrs, "class", [...classes].join(" "));
    attrs = setAttr(attrs, "style", [ownStyle, rootStyle].filter(Boolean).join(";"));
    attrs = setAttr(attrs, "data-highlighted", isDiff ? `diff:${target}` : target);
    return `<pre${attrs}>${gapA}<code${codeAttrs}>${body}</code>${gapB}</pre>`;
  });

  if (!/<pre\b[^>]*\bclass="[^"]*\bhl\b/.test(rewritten)) return rewritten;
  const style = `<style data-highlight>\n${CSS}\n</style>\n`;
  const withoutOld = rewritten.replace(STYLE_TAG, "");
  if (/<\/head>/i.test(withoutOld)) return withoutOld.replace(/<\/head>/i, `${style}</head>`);
  return style + withoutOld;
}

async function main(): Promise<number> {
  const args = process.argv.slice(2);
  const rootIndex = args.indexOf("--root");
  const root = rootIndex >= 0 ? args[rootIndex + 1] : undefined;
  const files = rootIndex >= 0 ? args.filter((_, i) => i !== rootIndex && i !== rootIndex + 1) : args;
  if (!files.length || files.includes("-h") || files.includes("--help") || (rootIndex >= 0 && !root)) {
    console.error("usage: node highlight.mts page.html [more.html ...] [--root <repo>]");
    return files.includes("-h") || files.includes("--help") ? 0 : 2;
  }
  const highlighter = await createHighlighter();
  let failed = false;
  for (const file of files) {
    let html: string;
    try {
      html = readFileSync(file, "utf8");
    } catch (error) {
      console.error(`highlight: cannot read ${file}: ${(error as Error).message}`);
      failed = true;
      continue;
    }
    const stats: Stats = { highlighted: 0, diffs: 0, plain: 0, skipped: [], notes: [] };
    const output = highlightHtml(highlighter, html, stats, root);
    if (output !== html) writeFileSync(file, output);
    for (const note of [...stats.skipped, ...stats.notes]) console.error(`${file}: ${note}`);
    console.error(`${file}: ${stats.highlighted} code, ${stats.diffs} diff, ${stats.plain} plain, ${stats.skipped.length} skipped`);
  }
  return failed ? 1 : 0;
}

process.exitCode = await main();
