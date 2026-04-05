/**
 * Files Extension
 *
 * /files command lists files in the current git tree (plus session-referenced files)
 * and offers quick actions like reveal in yazi, edit in nvim, diff with delta/difftastic, etc.
 *
 * Adapted for a tmux + neovim + yazi workflow with Catppuccin Mocha theming.
 */

import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import {
  Container,
  fuzzyFilter,
  Input,
  matchesKey,
  type SelectItem,
  SelectList,
  Spacer,
  Text,
} from "@mariozechner/pi-tui";

// ── Types ──────────────────────────────────────────────────────────────

type ContentBlock = {
  type?: string;
  text?: string;
  arguments?: Record<string, unknown>;
};

type FileReference = {
  path: string;
  display: string;
  exists: boolean;
  isDirectory: boolean;
};

type FileEntry = {
  canonicalPath: string;
  resolvedPath: string;
  displayPath: string;
  exists: boolean;
  isDirectory: boolean;
  status?: string;
  inRepo: boolean;
  isTracked: boolean;
  isReferenced: boolean;
  hasSessionChange: boolean;
  lastTimestamp: number;
};

type GitStatusEntry = {
  status: string;
  exists: boolean;
  isDirectory: boolean;
};

type FileToolName = "write" | "edit";

type SessionFileChange = {
  operations: Set<FileToolName>;
  lastTimestamp: number;
};

type FileAction = "edit" | "diffDelta" | "diffDifftastic" | "reveal" | "open" | "addToPrompt";

// ── Nerd Font Icons ────────────────────────────────────────────────────

const ICONS: Record<string, string> = {
  // directories
  dir: "\uf07c ",
  // file types (Seti-UI / devicons range — works with Nerd Fonts)
  ts: "\ue628 ",
  tsx: "\ue628 ",
  js: "\ue74e ",
  jsx: "\ue74e ",
  json: "\ue60b ",
  jsonl: "\ue60b ",
  nix: "\uf313 ",
  lua: "\ue620 ",
  py: "\ue73c ",
  rs: "\ue7a8 ",
  go: "\ue627 ",
  sh: "\uf489 ",
  bash: "\uf489 ",
  md: "\ue73e ",
  toml: "\ue6b2 ",
  yaml: "\ue6a8 ",
  yml: "\ue6a8 ",
  lock: "\uf023 ",
  gitignore: "\ue702 ",
  conf: "\ue615 ",
  cfg: "\ue615 ",
  ini: "\ue615 ",
  kdl: "\ue615 ",
  css: "\ue749 ",
  html: "\ue736 ",
  svg: "\uf1c5 ",
  png: "\uf1c5 ",
  jpg: "\uf1c5 ",
  gif: "\uf1c5 ",
  default: "\uf15b ",
};

const getFileIcon = (filePath: string, isDirectory: boolean): string => {
  if (isDirectory) return ICONS.dir;
  const basename = path.basename(filePath);
  const ext = path.extname(basename).slice(1).toLowerCase();

  // check full basename first (e.g. .gitignore)
  if (basename.startsWith(".git")) return ICONS.gitignore;
  if (basename === "flake.lock" || basename.endsWith(".lock")) return ICONS.lock;

  return ICONS[ext] ?? ICONS.default;
};

// ── ANSI helpers (Catppuccin Mocha palette) ────────────────────────────

const ansi = {
  green: (s: string) => `\x1b[38;2;166;227;161m${s}\x1b[0m`, // base0B - green
  yellow: (s: string) => `\x1b[38;2;249;226;175m${s}\x1b[0m`, // base0A - yellow
  red: (s: string) => `\x1b[38;2;243;139;168m${s}\x1b[0m`, // base08 - red
  blue: (s: string) => `\x1b[38;2;137;180;250m${s}\x1b[0m`, // base0D - blue
  cyan: (s: string) => `\x1b[38;2;148;226;213m${s}\x1b[0m`, // base0B - teal
  mauve: (s: string) => `\x1b[38;2;203;166;247m${s}\x1b[0m`, // base0E - mauve
  peach: (s: string) => `\x1b[38;2;250;179;135m${s}\x1b[0m`, // base09 - peach
  dim: (s: string) => `\x1b[38;2;108;112;134m${s}\x1b[0m`, // overlay0
  bold: (s: string) => `\x1b[1m${s}\x1b[22m`,
};

// ── Reference extraction ───────────────────────────────────────────────

const FILE_TAG_REGEX = /<file\s+name=["']([^"']+)["']>/g;
const FILE_URL_REGEX = /file:\/\/[^\s"'<>]+/g;
const PATH_REGEX = /(?:^|[\s"'`([{<])((?:~|\/)[^\s"'`<>)}\]]+)/g;

const extractFileReferencesFromText = (text: string): string[] => {
  const refs: string[] = [];
  for (const match of text.matchAll(FILE_TAG_REGEX)) refs.push(match[1]);
  for (const match of text.matchAll(FILE_URL_REGEX)) refs.push(match[0]);
  for (const match of text.matchAll(PATH_REGEX)) refs.push(match[1]);
  return refs;
};

const extractPathsFromToolArgs = (args: unknown): string[] => {
  if (!args || typeof args !== "object") return [];
  const refs: string[] = [];
  const record = args as Record<string, unknown>;
  for (const key of ["path", "file", "filePath", "filepath", "fileName", "filename"] as const) {
    const v = record[key];
    if (typeof v === "string") refs.push(v);
  }
  for (const key of ["paths", "files", "filePaths"] as const) {
    const v = record[key];
    if (Array.isArray(v)) for (const item of v) if (typeof item === "string") refs.push(item);
  }
  return refs;
};

const extractFileReferencesFromContent = (content: unknown): string[] => {
  if (typeof content === "string") return extractFileReferencesFromText(content);
  if (!Array.isArray(content)) return [];
  const refs: string[] = [];
  for (const part of content) {
    if (!part || typeof part !== "object") continue;
    const block = part as ContentBlock;
    if (block.type === "text" && typeof block.text === "string")
      refs.push(...extractFileReferencesFromText(block.text));
    if (block.type === "toolCall") refs.push(...extractPathsFromToolArgs(block.arguments));
  }
  return refs;
};

const extractFileReferencesFromEntry = (entry: SessionEntry): string[] => {
  if (entry.type === "message") return extractFileReferencesFromContent(entry.message.content);
  if (entry.type === "custom_message") return extractFileReferencesFromContent(entry.content);
  return [];
};

// ── Path normalization ─────────────────────────────────────────────────

const sanitizeReference = (raw: string): string => {
  let value = raw.trim();
  value = value.replace(/^["'`(<\[]+/, "");
  value = value.replace(/[>"'`,;).\]]+$/, "");
  value = value.replace(/[.,;:]+$/, "");
  return value;
};

const isCommentLikeReference = (value: string): boolean => value.startsWith("//");

const stripLineSuffix = (value: string): string => {
  let result = value.replace(/#L\d+(C\d+)?$/i, "");
  const lastSeparator = Math.max(result.lastIndexOf("/"), result.lastIndexOf("\\"));
  const segmentStart = lastSeparator >= 0 ? lastSeparator + 1 : 0;
  const segment = result.slice(segmentStart);
  const colonIndex = segment.indexOf(":");
  if (colonIndex >= 0 && /\d/.test(segment[colonIndex + 1] ?? "")) {
    result = result.slice(0, segmentStart + colonIndex);
    return result;
  }
  const lastColon = result.lastIndexOf(":");
  if (lastColon > lastSeparator) {
    const suffix = result.slice(lastColon + 1);
    if (/^\d+(?::\d+)?$/.test(suffix)) result = result.slice(0, lastColon);
  }
  return result;
};

const normalizeReferencePath = (raw: string, cwd: string): string | null => {
  let candidate = sanitizeReference(raw);
  if (!candidate || isCommentLikeReference(candidate)) return null;

  if (candidate.startsWith("file://")) {
    try {
      candidate = fileURLToPath(candidate);
    } catch {
      return null;
    }
  }

  candidate = stripLineSuffix(candidate);
  if (!candidate || isCommentLikeReference(candidate)) return null;
  if (candidate.startsWith("~")) candidate = path.join(os.homedir(), candidate.slice(1));
  if (!path.isAbsolute(candidate)) candidate = path.resolve(cwd, candidate);
  candidate = path.normalize(candidate);
  const root = path.parse(candidate).root;
  if (candidate.length > root.length) candidate = candidate.replace(/[\\/]+$/, "");
  return candidate;
};

const formatDisplayPath = (absolutePath: string, cwd: string): string => {
  const normalizedCwd = path.resolve(cwd);
  if (absolutePath.startsWith(normalizedCwd + path.sep)) {
    return path.relative(normalizedCwd, absolutePath);
  }
  return absolutePath;
};

// ── File collection ────────────────────────────────────────────────────

const collectRecentFileReferences = (
  entries: SessionEntry[],
  cwd: string,
  limit: number,
): FileReference[] => {
  const results: FileReference[] = [];
  const seen = new Set<string>();

  for (let i = entries.length - 1; i >= 0 && results.length < limit; i -= 1) {
    const refs = extractFileReferencesFromEntry(entries[i]);
    for (let j = refs.length - 1; j >= 0 && results.length < limit; j -= 1) {
      const normalized = normalizeReferencePath(refs[j], cwd);
      if (!normalized || seen.has(normalized)) continue;
      seen.add(normalized);

      let exists = false;
      let isDirectory = false;
      if (existsSync(normalized)) {
        exists = true;
        isDirectory = statSync(normalized).isDirectory();
      }
      results.push({ path: normalized, display: formatDisplayPath(normalized, cwd), exists, isDirectory });
    }
  }
  return results;
};

const findLatestFileReference = (entries: SessionEntry[], cwd: string): FileReference | null => {
  const refs = collectRecentFileReferences(entries, cwd, 100);
  return refs.find((ref) => ref.exists) ?? null;
};

const toCanonicalPath = (
  inputPath: string,
): { canonicalPath: string; isDirectory: boolean } | null => {
  if (!existsSync(inputPath)) return null;
  try {
    const canonicalPath = realpathSync(inputPath);
    const stats = statSync(canonicalPath);
    return { canonicalPath, isDirectory: stats.isDirectory() };
  } catch {
    return null;
  }
};

const toCanonicalPathMaybeMissing = (
  inputPath: string,
): { canonicalPath: string; isDirectory: boolean; exists: boolean } | null => {
  const resolvedPath = path.resolve(inputPath);
  if (!existsSync(resolvedPath)) {
    return { canonicalPath: path.normalize(resolvedPath), isDirectory: false, exists: false };
  }
  try {
    const canonicalPath = realpathSync(resolvedPath);
    const stats = statSync(canonicalPath);
    return { canonicalPath, isDirectory: stats.isDirectory(), exists: true };
  } catch {
    return { canonicalPath: path.normalize(resolvedPath), isDirectory: false, exists: true };
  }
};

const collectSessionFileChanges = (
  entries: SessionEntry[],
  cwd: string,
): Map<string, SessionFileChange> => {
  const toolCalls = new Map<string, { path: string; name: FileToolName }>();

  for (const entry of entries) {
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if (msg.role === "assistant" && Array.isArray(msg.content)) {
      for (const block of msg.content) {
        if (block.type === "toolCall") {
          const name = block.name as FileToolName;
          if (name === "write" || name === "edit") {
            const filePath = block.arguments?.path;
            if (filePath && typeof filePath === "string") {
              toolCalls.set(block.id, { path: filePath, name });
            }
          }
        }
      }
    }
  }

  const fileMap = new Map<string, SessionFileChange>();
  for (const entry of entries) {
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if (msg.role === "toolResult") {
      const toolCall = toolCalls.get(msg.toolCallId);
      if (!toolCall) continue;
      const resolvedPath = path.isAbsolute(toolCall.path)
        ? toolCall.path
        : path.resolve(cwd, toolCall.path);
      const canonical = toCanonicalPath(resolvedPath);
      if (!canonical) continue;
      const existing = fileMap.get(canonical.canonicalPath);
      if (existing) {
        existing.operations.add(toolCall.name);
        if (msg.timestamp > existing.lastTimestamp) existing.lastTimestamp = msg.timestamp;
      } else {
        fileMap.set(canonical.canonicalPath, {
          operations: new Set([toolCall.name]),
          lastTimestamp: msg.timestamp,
        });
      }
    }
  }
  return fileMap;
};

// ── Git helpers ────────────────────────────────────────────────────────

const splitNullSeparated = (value: string): string[] => value.split("\0").filter(Boolean);

const getGitRoot = async (pi: ExtensionAPI, cwd: string): Promise<string | null> => {
  const result = await pi.exec("git", ["rev-parse", "--show-toplevel"], { cwd });
  if (result.code !== 0) return null;
  const root = result.stdout.trim();
  return root || null;
};

const getGitStatusMap = async (
  pi: ExtensionAPI,
  cwd: string,
): Promise<Map<string, GitStatusEntry>> => {
  const statusMap = new Map<string, GitStatusEntry>();
  const statusResult = await pi.exec("git", ["status", "--porcelain=1", "-z"], { cwd });
  if (statusResult.code !== 0 || !statusResult.stdout) return statusMap;

  const entries = splitNullSeparated(statusResult.stdout);
  for (let i = 0; i < entries.length; i += 1) {
    const entry = entries[i];
    if (!entry || entry.length < 4) continue;
    const status = entry.slice(0, 2);
    const statusLabel = status.replace(/\s/g, "") || status.trim();
    let filePath = entry.slice(3);
    if ((status.startsWith("R") || status.startsWith("C")) && entries[i + 1]) {
      filePath = entries[i + 1];
      i += 1;
    }
    if (!filePath) continue;
    const resolved = path.isAbsolute(filePath) ? filePath : path.resolve(cwd, filePath);
    const canonical = toCanonicalPathMaybeMissing(resolved);
    if (!canonical) continue;
    statusMap.set(canonical.canonicalPath, {
      status: statusLabel,
      exists: canonical.exists,
      isDirectory: canonical.isDirectory,
    });
  }
  return statusMap;
};

const getGitFiles = async (
  pi: ExtensionAPI,
  gitRoot: string,
): Promise<{
  tracked: Set<string>;
  files: Array<{ canonicalPath: string; isDirectory: boolean }>;
}> => {
  const tracked = new Set<string>();
  const files: Array<{ canonicalPath: string; isDirectory: boolean }> = [];

  const trackedResult = await pi.exec("git", ["ls-files", "-z"], { cwd: gitRoot });
  if (trackedResult.code === 0 && trackedResult.stdout) {
    for (const relativePath of splitNullSeparated(trackedResult.stdout)) {
      const resolvedPath = path.resolve(gitRoot, relativePath);
      const canonical = toCanonicalPath(resolvedPath);
      if (!canonical) continue;
      tracked.add(canonical.canonicalPath);
      files.push(canonical);
    }
  }

  const untrackedResult = await pi.exec(
    "git",
    ["ls-files", "-z", "--others", "--exclude-standard"],
    { cwd: gitRoot },
  );
  if (untrackedResult.code === 0 && untrackedResult.stdout) {
    for (const relativePath of splitNullSeparated(untrackedResult.stdout)) {
      const resolvedPath = path.resolve(gitRoot, relativePath);
      const canonical = toCanonicalPath(resolvedPath);
      if (!canonical) continue;
      files.push(canonical);
    }
  }

  return { tracked, files };
};

// ── Build file entries ─────────────────────────────────────────────────

const buildFileEntries = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
): Promise<{ files: FileEntry[]; gitRoot: string | null }> => {
  const entries = ctx.sessionManager.getBranch();
  const sessionChanges = collectSessionFileChanges(entries, ctx.cwd);
  const gitRoot = await getGitRoot(pi, ctx.cwd);
  const statusMap = gitRoot
    ? await getGitStatusMap(pi, gitRoot)
    : new Map<string, GitStatusEntry>();

  let trackedSet = new Set<string>();
  let gitFiles: Array<{ canonicalPath: string; isDirectory: boolean }> = [];
  if (gitRoot) {
    const gitListing = await getGitFiles(pi, gitRoot);
    trackedSet = gitListing.tracked;
    gitFiles = gitListing.files;
  }

  const fileMap = new Map<string, FileEntry>();

  const upsertFile = (
    data: Partial<FileEntry> & { canonicalPath: string; isDirectory: boolean },
  ) => {
    const existing = fileMap.get(data.canonicalPath);
    const displayPath = data.displayPath ?? formatDisplayPath(data.canonicalPath, ctx.cwd);

    if (existing) {
      fileMap.set(data.canonicalPath, {
        ...existing,
        ...data,
        displayPath,
        exists: data.exists ?? existing.exists,
        isDirectory: data.isDirectory ?? existing.isDirectory,
        isReferenced: existing.isReferenced || data.isReferenced === true,
        inRepo: existing.inRepo || data.inRepo === true,
        isTracked: existing.isTracked || data.isTracked === true,
        hasSessionChange: existing.hasSessionChange || data.hasSessionChange === true,
        lastTimestamp: Math.max(existing.lastTimestamp, data.lastTimestamp ?? 0),
      });
      return;
    }

    fileMap.set(data.canonicalPath, {
      canonicalPath: data.canonicalPath,
      resolvedPath: data.resolvedPath ?? data.canonicalPath,
      displayPath,
      exists: data.exists ?? true,
      isDirectory: data.isDirectory,
      status: data.status,
      inRepo: data.inRepo ?? false,
      isTracked: data.isTracked ?? false,
      isReferenced: data.isReferenced ?? false,
      hasSessionChange: data.hasSessionChange ?? false,
      lastTimestamp: data.lastTimestamp ?? 0,
    });
  };

  for (const file of gitFiles) {
    upsertFile({
      canonicalPath: file.canonicalPath,
      resolvedPath: file.canonicalPath,
      isDirectory: file.isDirectory,
      exists: true,
      status: statusMap.get(file.canonicalPath)?.status,
      inRepo: true,
      isTracked: trackedSet.has(file.canonicalPath),
    });
  }

  for (const [canonicalPath, statusEntry] of statusMap.entries()) {
    if (fileMap.has(canonicalPath)) continue;
    const inRepo =
      gitRoot !== null &&
      !path.relative(gitRoot, canonicalPath).startsWith("..") &&
      !path.isAbsolute(path.relative(gitRoot, canonicalPath));
    upsertFile({
      canonicalPath,
      resolvedPath: canonicalPath,
      isDirectory: statusEntry.isDirectory,
      exists: statusEntry.exists,
      status: statusEntry.status,
      inRepo,
      isTracked: trackedSet.has(canonicalPath) || statusEntry.status !== "??",
    });
  }

  const references = collectRecentFileReferences(entries, ctx.cwd, 200).filter((ref) => ref.exists);
  for (const ref of references) {
    const canonical = toCanonicalPath(ref.path);
    if (!canonical) continue;
    const inRepo =
      gitRoot !== null &&
      !path.relative(gitRoot, canonical.canonicalPath).startsWith("..") &&
      !path.isAbsolute(path.relative(gitRoot, canonical.canonicalPath));
    upsertFile({
      canonicalPath: canonical.canonicalPath,
      resolvedPath: canonical.canonicalPath,
      isDirectory: canonical.isDirectory,
      exists: true,
      status: statusMap.get(canonical.canonicalPath)?.status,
      inRepo,
      isTracked: trackedSet.has(canonical.canonicalPath),
      isReferenced: true,
    });
  }

  for (const [canonicalPath, change] of sessionChanges.entries()) {
    const canonical = toCanonicalPath(canonicalPath);
    if (!canonical) continue;
    const inRepo =
      gitRoot !== null &&
      !path.relative(gitRoot, canonical.canonicalPath).startsWith("..") &&
      !path.isAbsolute(path.relative(gitRoot, canonical.canonicalPath));
    upsertFile({
      canonicalPath: canonical.canonicalPath,
      resolvedPath: canonical.canonicalPath,
      isDirectory: canonical.isDirectory,
      exists: true,
      status: statusMap.get(canonical.canonicalPath)?.status,
      inRepo,
      isTracked: trackedSet.has(canonical.canonicalPath),
      hasSessionChange: true,
      lastTimestamp: change.lastTimestamp,
    });
  }

  const files = Array.from(fileMap.values()).sort((a, b) => {
    const aDirty = Boolean(a.status);
    const bDirty = Boolean(b.status);
    if (aDirty !== bDirty) return aDirty ? -1 : 1;
    if (a.inRepo !== b.inRepo) return a.inRepo ? -1 : 1;
    if (a.hasSessionChange !== b.hasSessionChange) return a.hasSessionChange ? -1 : 1;
    if (a.lastTimestamp !== b.lastTimestamp) return b.lastTimestamp - a.lastTimestamp;
    if (a.isReferenced !== b.isReferenced) return a.isReferenced ? -1 : 1;
    return a.displayPath.localeCompare(b.displayPath);
  });

  return { files, gitRoot };
};

// ── Colorized file label ───────────────────────────────────────────────

const getStatusColor = (status: string | undefined): ((s: string) => string) | null => {
  if (!status) return null;
  const code = status.charAt(0);
  switch (code) {
    case "M":
      return ansi.yellow; // modified
    case "A":
      return ansi.green; // added
    case "D":
      return ansi.red; // deleted
    case "R":
      return ansi.mauve; // renamed
    case "?":
      return ansi.cyan; // untracked
    case "U":
      return ansi.red; // unmerged
    default:
      return ansi.peach;
  }
};

const formatFileLabel = (file: FileEntry): string => {
  const icon = getFileIcon(file.displayPath, file.isDirectory);
  const statusColor = getStatusColor(file.status);
  const statusBadge = file.status ? ` [${file.status}]` : "";

  let name = file.displayPath;
  if (file.isDirectory) name = ansi.blue(ansi.bold(name));
  else if (statusColor) name = statusColor(name);

  const coloredBadge = statusBadge && statusColor ? statusColor(statusBadge) : statusBadge;
  const sessionMark = file.hasSessionChange ? ansi.mauve(" ●") : "";
  const refMark = file.isReferenced && !file.hasSessionChange ? ansi.dim(" ◆") : "";

  return `${icon}${name}${coloredBadge}${sessionMark}${refMark}`;
};

// ── tmux helpers ───────────────────────────────────────────────────────

const inTmux = (): boolean => Boolean(process.env.TMUX);

const tmuxSplitRun = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  command: string,
  cwd?: string,
): Promise<void> => {
  if (!inTmux()) {
    ctx.ui.notify("Not inside a tmux session", "error");
    return;
  }
  const args = ["split-window", "-h", "-c", cwd ?? ctx.cwd, command];
  const result = await pi.exec("tmux", args);
  if (result.code !== 0) {
    ctx.ui.notify(result.stderr?.trim() || "tmux split failed", "error");
  }
};

// ── Actions ────────────────────────────────────────────────────────────

const editInNvim = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  target: FileEntry,
): Promise<void> => {
  if (!existsSync(target.resolvedPath) && !target.isDirectory) {
    // new file - nvim can create it
  }
  if (target.isDirectory) {
    ctx.ui.notify("Cannot edit a directory", "warning");
    return;
  }

  await tmuxSplitRun(
    pi,
    ctx,
    `nvim '${target.resolvedPath.replace(/'/g, "'\\''")}'`,
    path.dirname(target.resolvedPath),
  );
};

const diffWithDelta = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  target: FileEntry,
  gitRoot: string,
): Promise<void> => {
  const relativePath = path.relative(gitRoot, target.resolvedPath).split(path.sep).join("/");
  // Use git diff piped through delta (which is the configured pager, so just git diff works)
  // but we want it in a split, so run in a subshell
  const cmd = `git diff HEAD -- '${relativePath.replace(/'/g, "'\\''")}' | delta --paging=always; read -n1 -r -p 'Press any key to close...'`;
  await tmuxSplitRun(pi, ctx, `bash -c "${cmd.replace(/"/g, '\\"')}"`, gitRoot);
};

const diffWithDifftastic = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  target: FileEntry,
  gitRoot: string,
): Promise<void> => {
  const relativePath = path.relative(gitRoot, target.resolvedPath).split(path.sep).join("/");
  // uses the git ddiff alias (difftastic)
  const cmd = `git -c diff.external=difft diff HEAD -- '${relativePath.replace(/'/g, "'\\''")}'; read -n1 -r -p 'Press any key to close...'`;
  await tmuxSplitRun(pi, ctx, `bash -c "${cmd.replace(/"/g, '\\"')}"`, gitRoot);
};

const revealInYazi = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  target: FileEntry,
): Promise<void> => {
  if (!existsSync(target.resolvedPath)) {
    ctx.ui.notify(`Not found: ${target.displayPath}`, "error");
    return;
  }

  // yazi takes positional [ENTRIES] to set the focused entry
  // for files, pass the file path so yazi opens its parent dir with that file selected
  const yaziTarget = target.resolvedPath.replace(/'/g, "'\\''");
  const cwd = target.isDirectory ? target.resolvedPath : path.dirname(target.resolvedPath);

  await tmuxSplitRun(pi, ctx, `yazi '${yaziTarget}'`, cwd);
};

const openPath = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  target: FileEntry,
): Promise<void> => {
  if (!existsSync(target.resolvedPath)) {
    ctx.ui.notify(`Not found: ${target.displayPath}`, "error");
    return;
  }
  const result = await pi.exec("xdg-open", [target.resolvedPath]);
  if (result.code !== 0) {
    ctx.ui.notify(result.stderr?.trim() || `Failed to open ${target.displayPath}`, "error");
  }
};

const addFileToPrompt = (ctx: ExtensionContext, target: FileEntry): void => {
  const mention = `@${target.displayPath || target.resolvedPath}`;
  const current = ctx.ui.getEditorText();
  const separator = current && !current.endsWith(" ") ? " " : "";
  ctx.ui.setEditorText(`${current}${separator}${mention}`);
  ctx.ui.notify(`Added ${mention} to prompt`, "info");
};

// ── Action selector ────────────────────────────────────────────────────

const showActionSelector = async (
  ctx: ExtensionContext,
  options: { canDiffDelta: boolean; canDiffDifftastic: boolean; canEdit: boolean },
): Promise<FileAction | null> => {
  const actions: SelectItem[] = [
    ...(options.canEdit ? [{ value: "edit", label: " Edit in nvim (tmux split)" }] : []),
    ...(options.canDiffDelta
      ? [{ value: "diffDelta", label: " Diff with delta" }]
      : []),
    ...(options.canDiffDifftastic
      ? [{ value: "diffDifftastic", label: " Diff with difftastic" }]
      : []),
    { value: "reveal", label: "󰙅 Reveal in yazi (tmux split)" },
    { value: "open", label: " Open with xdg-open" },
    { value: "addToPrompt", label: " Add to prompt" },
  ];

  return ctx.ui.custom<FileAction | null>((tui, theme, _kb, done) => {
    const container = new Container();
    container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));
    container.addChild(new Text(theme.fg("accent", theme.bold(" Choose action")), 0, 0));

    const selectList = new SelectList(actions, actions.length, {
      selectedPrefix: (text) => theme.fg("accent", text),
      selectedText: (text) => theme.fg("accent", text),
      description: (text) => theme.fg("muted", text),
      scrollInfo: (text) => theme.fg("dim", text),
      noMatch: (text) => theme.fg("warning", text),
    });

    selectList.onSelect = (item) => done(item.value as FileAction);
    selectList.onCancel = () => done(null);
    container.addChild(selectList);
    container.addChild(new Text(theme.fg("dim", " enter confirm · esc cancel"), 0, 0));
    container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));

    return {
      render(width: number) {
        return container.render(width);
      },
      invalidate() {
        container.invalidate();
      },
      handleInput(data: string) {
        selectList.handleInput(data);
        tui.requestRender();
      },
    };
  });
};

// ── File selector ──────────────────────────────────────────────────────

const showFileSelector = async (
  ctx: ExtensionContext,
  files: FileEntry[],
  selectedPath?: string | null,
  gitRoot?: string | null,
): Promise<{ selected: FileEntry | null; quickAction: FileAction | null }> => {
  const items: SelectItem[] = files.map((file) => ({
    value: file.canonicalPath,
    label: formatFileLabel(file),
  }));

  let quickAction: FileAction | null = null;

  const selection = await ctx.ui.custom<string | null>((tui, theme, keybindings, done) => {
    const container = new Container();
    container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));
    container.addChild(new Text(theme.fg("accent", theme.bold("  Files")), 0, 0));

    const searchInput = new Input();
    container.addChild(searchInput);
    container.addChild(new Spacer(1));

    const listContainer = new Container();
    container.addChild(listContainer);

    const hints = [
      "type to filter",
      "enter select",
      "ctrl+e nvim",
      "ctrl+d delta",
      "ctrl+alt+d difftastic",
      "ctrl+y yazi",
      "esc cancel",
    ];
    container.addChild(new Text(theme.fg("dim", ` ${hints.join(" · ")}`), 0, 0));
    container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));

    let filteredItems = items;
    let selectList: SelectList | null = null;

    const updateList = () => {
      listContainer.clear();
      if (filteredItems.length === 0) {
        listContainer.addChild(new Text(theme.fg("warning", "  No matching files"), 0, 0));
        selectList = null;
        return;
      }
      selectList = new SelectList(filteredItems, Math.min(filteredItems.length, 16), {
        selectedPrefix: (text) => theme.fg("accent", text),
        selectedText: (text) => theme.fg("accent", text),
        description: (text) => theme.fg("muted", text),
        scrollInfo: (text) => theme.fg("dim", text),
        noMatch: (text) => theme.fg("warning", text),
      });
      if (selectedPath) {
        const index = filteredItems.findIndex((item) => item.value === selectedPath);
        if (index >= 0) selectList.setSelectedIndex(index);
      }
      selectList.onSelect = (item) => done(item.value as string);
      selectList.onCancel = () => done(null);
      listContainer.addChild(selectList);
    };

    const applyFilter = () => {
      const query = searchInput.getValue();
      filteredItems = query
        ? fuzzyFilter(
            items,
            query,
            (item) => `${item.label} ${item.value} ${item.description ?? ""}`,
          )
        : items;
      updateList();
    };

    applyFilter();

    return {
      render(width: number) {
        return container.render(width);
      },
      invalidate() {
        container.invalidate();
      },
      handleInput(data: string) {
        const getSelectedFile = () => {
          const selected = selectList?.getSelectedItem();
          return selected ? files.find((f) => f.canonicalPath === selected.value) : undefined;
        };

        // ctrl+e → edit in nvim
        if (matchesKey(data, "ctrl+e")) {
          const file = getSelectedFile();
          if (file && !file.isDirectory) {
            quickAction = "edit";
            done(file.canonicalPath);
            return;
          }
        }

        // ctrl+d → diff with delta
        if (matchesKey(data, "ctrl+d")) {
          const file = getSelectedFile();
          if (file?.isTracked && !file.isDirectory && gitRoot) {
            quickAction = "diffDelta";
            done(file.canonicalPath);
            return;
          } else {
            ctx.ui.notify("Diff only available for tracked files", "warning");
          }
          return;
        }

        // ctrl+alt+d → diff with difftastic
        if (matchesKey(data, "ctrl+alt+d")) {
          const file = getSelectedFile();
          if (file?.isTracked && !file.isDirectory && gitRoot) {
            quickAction = "diffDifftastic";
            done(file.canonicalPath);
            return;
          } else {
            ctx.ui.notify("Diff only available for tracked files", "warning");
          }
          return;
        }

        // ctrl+y → reveal in yazi
        if (matchesKey(data, "ctrl+y")) {
          const file = getSelectedFile();
          if (file) {
            quickAction = "reveal";
            done(file.canonicalPath);
            return;
          }
        }

        if (
          keybindings.matches(data, "tui.select.up") ||
          keybindings.matches(data, "tui.select.down") ||
          keybindings.matches(data, "tui.select.confirm") ||
          keybindings.matches(data, "tui.select.cancel")
        ) {
          if (selectList) {
            selectList.handleInput(data);
          } else if (keybindings.matches(data, "tui.select.cancel")) {
            done(null);
          }
          tui.requestRender();
          return;
        }

        searchInput.handleInput(data);
        applyFilter();
        tui.requestRender();
      },
    };
  });

  const selected = selection
    ? (files.find((file) => file.canonicalPath === selection) ?? null)
    : null;
  return { selected, quickAction };
};

// ── Main browser loop ──────────────────────────────────────────────────

const runFileBrowser = async (pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> => {
  if (!ctx.hasUI) {
    ctx.ui.notify("Files requires interactive mode", "error");
    return;
  }

  const { files, gitRoot } = await buildFileEntries(pi, ctx);
  if (files.length === 0) {
    ctx.ui.notify("No files found", "info");
    return;
  }

  let lastSelectedPath: string | null = null;

  while (true) {
    const { selected, quickAction } = await showFileSelector(ctx, files, lastSelectedPath, gitRoot);
    if (!selected) return;

    lastSelectedPath = selected.canonicalPath;

    const canEdit = !selected.isDirectory && selected.exists;
    const canDiff = selected.isTracked && !selected.isDirectory && Boolean(gitRoot);

    // Resolve the action (quick action from shortcut, or show menu)
    let action: FileAction | null = quickAction;
    if (!action) {
      action = await showActionSelector(ctx, {
        canEdit,
        canDiffDelta: canDiff,
        canDiffDifftastic: canDiff,
      });
    }
    if (!action) continue;

    // Execute and close
    switch (action) {
      case "edit":
        await editInNvim(pi, ctx, selected);
        return;
      case "diffDelta":
        if (gitRoot) await diffWithDelta(pi, ctx, selected, gitRoot);
        return;
      case "diffDifftastic":
        if (gitRoot) await diffWithDifftastic(pi, ctx, selected, gitRoot);
        return;
      case "reveal":
        await revealInYazi(pi, ctx, selected);
        return;
      case "open":
        await openPath(pi, ctx, selected);
        return;
      case "addToPrompt":
        addFileToPrompt(ctx, selected);
        return;
    }
  }
};

// ── Extension entry point ──────────────────────────────────────────────

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("files", {
    description: "Browse files with git status and session references",
    handler: async (_args, ctx) => {
      await runFileBrowser(pi, ctx);
    },
  });

  pi.registerShortcut("ctrl+shift+o", {
    description: "Browse project files",
    handler: async (ctx) => {
      await runFileBrowser(pi, ctx);
    },
  });

  pi.registerShortcut("ctrl+shift+f", {
    description: "Reveal latest file reference in yazi",
    handler: async (ctx) => {
      const entries = ctx.sessionManager.getBranch();
      const latest = findLatestFileReference(entries, ctx.cwd);

      if (!latest) {
        ctx.ui.notify("No file reference found in session", "warning");
        return;
      }

      const canonical = toCanonicalPath(latest.path);
      if (!canonical) {
        ctx.ui.notify(`Not found: ${latest.display}`, "error");
        return;
      }

      await revealInYazi(pi, ctx, {
        canonicalPath: canonical.canonicalPath,
        resolvedPath: canonical.canonicalPath,
        displayPath: latest.display,
        exists: true,
        isDirectory: canonical.isDirectory,
        status: undefined,
        inRepo: false,
        isTracked: false,
        isReferenced: true,
        hasSessionChange: false,
        lastTimestamp: 0,
      });
    },
  });
}
