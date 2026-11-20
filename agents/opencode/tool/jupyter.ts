import { tool } from "@opencode-ai/plugin";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";

const LIMITS = {
  perCellOutputChars: 4000,
  perCellOutputLines: 100,
  totalNotebookChars: 25000,
};

const IMAGE_DIR = "/tmp/opencode/jupyter";

interface NotebookCell {
  cell_type: "code" | "markdown" | "raw";
  id?: string;
  source: string | string[];
  outputs?: CellOutput[];
  execution_count?: number | null;
  metadata?: Record<string, unknown>;
}

interface StreamOutput {
  output_type: "stream";
  name: "stdout" | "stderr";
  text: string | string[];
}

interface ExecuteResultOutput {
  output_type: "execute_result";
  execution_count: number;
  data: Record<string, string | string[]>;
  metadata?: Record<string, unknown>;
}

interface DisplayDataOutput {
  output_type: "display_data";
  data: Record<string, string | string[]>;
  metadata?: Record<string, unknown>;
}

interface ErrorOutput {
  output_type: "error";
  ename: string;
  evalue: string;
  traceback: string[];
}

type CellOutput =
  | StreamOutput
  | ExecuteResultOutput
  | DisplayDataOutput
  | ErrorOutput;

interface Notebook {
  cells: NotebookCell[];
  metadata?: Record<string, unknown>;
  nbformat: number;
  nbformat_minor: number;
}

function truncateText(
  text: string,
  charLimit: number,
  lineLimit: number,
): { text: string; truncated: boolean } {
  let truncated = false;
  let result = text;

  const lines = result.split("\n");
  if (lines.length > lineLimit) {
    result = lines.slice(0, lineLimit).join("\n");
    truncated = true;
  }

  if (result.length > charLimit) {
    result = result.slice(0, charLimit);
    truncated = true;
  }

  return { text: result, truncated };
}

function cleanAnsi(text: string): string {
  const ESC = String.fromCharCode(0x1b);
  const ansiPattern = new RegExp(`${ESC}\\[[0-9;]*m`, "g");
  return text.replace(ansiPattern, "");
}

function normalizeSource(source: string | string[]): string {
  if (Array.isArray(source)) {
    return source.join("");
  }
  return source;
}

function sourceToArray(content: string): string[] {
  if (!content) return [];
  const lines = content.split("\n");
  return lines.map((line, i) => (i < lines.length - 1 ? `${line}\n` : line));
}

async function ensureImageDir(): Promise<void> {
  if (!existsSync(IMAGE_DIR)) {
    await mkdir(IMAGE_DIR, { recursive: true });
  }
}

async function saveImage(
  base64Data: string,
  mimeType: string,
  notebookName: string,
): Promise<string> {
  await ensureImageDir();

  const extMap: Record<string, string> = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/gif": "gif",
    "image/svg+xml": "svg",
    "image/webp": "webp",
  };
  const ext = extMap[mimeType] || "png";

  const uid = randomUUID().slice(0, 8);
  const safeName = notebookName
    .replace(/\.ipynb$/, "")
    .replace(/[^a-zA-Z0-9_-]/g, "_");
  const filename = `${safeName}-${uid}.${ext}`;
  const filepath = join(IMAGE_DIR, filename);

  const buffer = Buffer.from(base64Data, "base64");
  await writeFile(filepath, buffer);

  return filepath;
}

async function formatOutputs(
  outputs: CellOutput[],
  notebookName: string,
  cellIndex: number,
  notebookPath: string,
): Promise<{ text: string; truncated: boolean }> {
  if (!outputs || outputs.length === 0) {
    return { text: "", truncated: false };
  }

  const parts: string[] = [];
  let totalTruncated = false;

  for (const output of outputs) {
    switch (output.output_type) {
      case "stream": {
        const text = normalizeSource(output.text);
        const prefix = output.name === "stderr" ? "[stderr] " : "";
        const { text: truncatedText, truncated } = truncateText(
          text,
          LIMITS.perCellOutputChars,
          LIMITS.perCellOutputLines,
        );
        parts.push(`${prefix}${truncatedText}`);
        if (truncated) totalTruncated = true;
        break;
      }

      case "execute_result":
      case "display_data": {
        const imageTypes = [
          "image/png",
          "image/jpeg",
          "image/gif",
          "image/svg+xml",
          "image/webp",
        ];
        let hasImage = false;

        for (const mimeType of imageTypes) {
          if (output.data[mimeType]) {
            const base64Data = normalizeSource(output.data[mimeType]);
            try {
              const imagePath = await saveImage(
                base64Data,
                mimeType,
                notebookName,
              );
              parts.push(`[Image: ${imagePath}]`);
              hasImage = true;
            } catch {
              parts.push("[Image extraction failed]");
            }
            break;
          }
        }

        if (!hasImage && output.data["text/plain"]) {
          const text = normalizeSource(output.data["text/plain"]);
          const { text: truncatedText, truncated } = truncateText(
            text,
            LIMITS.perCellOutputChars,
            LIMITS.perCellOutputLines,
          );
          parts.push(truncatedText);
          if (truncated) totalTruncated = true;
        }
        break;
      }

      case "error": {
        const traceback = output.traceback
          .map((line) => cleanAnsi(line))
          .join("\n");
        const errorText = `${output.ename}: ${output.evalue}\n${traceback}`;
        const { text: truncatedText, truncated } = truncateText(
          errorText,
          LIMITS.perCellOutputChars,
          LIMITS.perCellOutputLines,
        );
        parts.push(truncatedText);
        if (truncated) totalTruncated = true;
        break;
      }
    }
  }

  let result = parts.join("\n");

  if (totalTruncated) {
    result += `\n[Output truncated. Use: cat ${notebookPath} | jq '.cells[${cellIndex}].outputs']`;
  }

  return { text: result, truncated: totalTruncated };
}

async function formatCell(
  cell: NotebookCell,
  cellIndex: number,
  notebookName: string,
  notebookPath: string,
): Promise<string> {
  const cellId = cell.id || `cell-${cellIndex}`;
  const source = normalizeSource(cell.source);

  let content = "";

  if (cell.cell_type === "markdown") {
    content = `<cell_type>markdown</cell_type>${source}`;
  } else if (cell.cell_type === "raw") {
    content = `<cell_type>raw</cell_type>${source}`;
  } else {
    content = source;
  }

  if (cell.cell_type === "code" && cell.outputs && cell.outputs.length > 0) {
    const { text: outputText } = await formatOutputs(
      cell.outputs,
      notebookName,
      cellIndex,
      notebookPath,
    );
    if (outputText) {
      content += `\n--- Output ---\n${outputText}`;
    }
  }

  return `<cell id="${cellId}">${content}</cell id="${cellId}">`;
}

function parseNotebook(content: string, filePath: string): Notebook {
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`Invalid JSON in notebook: ${filePath}`);
  }

  const notebook = parsed as Notebook;
  if (!notebook.cells || !Array.isArray(notebook.cells)) {
    throw new Error(
      `Not a valid Jupyter notebook (missing cells): ${filePath}`,
    );
  }

  return notebook;
}

function needsCellIdUpgrade(notebook: Notebook): boolean {
  return notebook.cells.some((cell) => !cell.id);
}

function generateCellId(): string {
  return randomUUID().replace(/-/g, "").slice(0, 8);
}

function upgradeNotebookCellIds(notebook: Notebook): boolean {
  let upgraded = false;

  for (const cell of notebook.cells) {
    if (!cell.id) {
      cell.id = generateCellId();
      upgraded = true;
    }
  }

  if (upgraded && notebook.nbformat === 4 && notebook.nbformat_minor < 5) {
    notebook.nbformat_minor = 5;
  }

  return upgraded;
}

export const read = tool({
  description:
    "Read a Jupyter notebook (.ipynb) file and return its cells in a structured format. " +
    "Code cells show source and outputs. Images are extracted to temporary files. " +
    "Large outputs are truncated with hints to access full content via jq. " +
    "Notebooks without cell IDs (pre-4.5 format) are automatically upgraded.",
  args: {
    file_path: tool.schema
      .string()
      .describe("Absolute path to the .ipynb file"),
  },
  async execute(args) {
    const { file_path } = args;

    if (!file_path.endsWith(".ipynb")) {
      throw new Error(`Not a Jupyter notebook file: ${file_path}`);
    }

    let content: string;
    try {
      content = await readFile(file_path, "utf-8");
    } catch (err) {
      const error = err as NodeJS.ErrnoException;
      if (error.code === "ENOENT") {
        throw new Error(`File not found: ${file_path}`);
      }
      throw new Error(`Failed to read file: ${file_path} - ${error.message}`);
    }

    const notebook = parseNotebook(content, file_path);
    const notebookName = basename(file_path);

    let upgradeNote = "";
    if (needsCellIdUpgrade(notebook)) {
      upgradeNotebookCellIds(notebook);
      const updatedContent = JSON.stringify(notebook, null, 1);
      await writeFile(file_path, updatedContent, "utf-8");
      upgradeNote =
        "[Note: Upgraded notebook to nbformat 4.5 by adding cell IDs]\n\n";
    }

    const formattedCells: string[] = [];
    let totalChars = 0;
    let truncatedNotebook = false;

    for (let i = 0; i < notebook.cells.length; i++) {
      const cell = notebook.cells[i];
      const formatted = await formatCell(cell, i, notebookName, file_path);

      if (totalChars + formatted.length > LIMITS.totalNotebookChars) {
        truncatedNotebook = true;
        const remaining = LIMITS.totalNotebookChars - totalChars;
        if (remaining > 100) {
          formattedCells.push(`${formatted.slice(0, remaining)}...`);
        }
        break;
      }

      formattedCells.push(formatted);
      totalChars += formatted.length;
    }

    let result = upgradeNote + formattedCells.join("\n\n");

    if (truncatedNotebook) {
      result +=
        `\n\n[Notebook truncated. Total cells: ${notebook.cells.length}. ` +
        "Use jq to inspect specific cells.]";
    }

    return result;
  },
});

export const write = tool({
  description:
    "Edit a Jupyter notebook (.ipynb) file. Supports three modes: " +
    "'replace' updates an existing cell's content, " +
    "'insert' adds a new cell after the specified cell_id (or at the beginning if omitted), " +
    "'delete' removes a cell. Use the read tool first to get cell IDs.",
  args: {
    notebook_path: tool.schema
      .string()
      .describe("Absolute path to the .ipynb file"),
    cell_id: tool.schema
      .string()
      .optional()
      .describe(
        "UUID of the target cell. Required for replace/delete. " +
          "For insert, specifies the cell after which to insert (omit to insert at beginning).",
      ),
    cell_type: tool.schema
      .enum(["code", "markdown"])
      .optional()
      .describe("Cell type. Required for insert mode."),
    new_source: tool.schema
      .string()
      .describe(
        "New content for the cell. Required for replace/insert. Can be empty for delete.",
      ),
    edit_mode: tool.schema
      .enum(["replace", "insert", "delete"])
      .default("replace")
      .describe("Edit operation: 'replace' (default), 'insert', or 'delete'"),
  },
  async execute(args) {
    const { notebook_path, cell_id, cell_type, new_source, edit_mode } = args;

    if (!notebook_path.endsWith(".ipynb")) {
      throw new Error(`Not a Jupyter notebook file: ${notebook_path}`);
    }

    let content: string;
    try {
      content = await readFile(notebook_path, "utf-8");
    } catch (err) {
      const error = err as NodeJS.ErrnoException;
      if (error.code === "ENOENT") {
        throw new Error(`File not found: ${notebook_path}`);
      }
      throw new Error(
        `Failed to read file: ${notebook_path} - ${error.message}`,
      );
    }

    const notebook = parseNotebook(content, notebook_path);

    const findCellIndex = (id: string): number => {
      const index = notebook.cells.findIndex((cell) => cell.id === id);
      if (index === -1) {
        throw new Error(`Cell not found with id: ${id}`);
      }
      return index;
    };

    let resultMessage: string;

    switch (edit_mode) {
      case "replace": {
        if (!cell_id) {
          throw new Error("cell_id is required for replace mode");
        }
        const index = findCellIndex(cell_id);
        notebook.cells[index].source = sourceToArray(new_source);
        if (notebook.cells[index].cell_type === "code") {
          notebook.cells[index].outputs = [];
          notebook.cells[index].execution_count = null;
        }
        resultMessage = `Replaced cell ${cell_id}`;
        break;
      }

      case "insert": {
        if (!cell_type) {
          throw new Error("cell_type is required for insert mode");
        }
        const newCellId = randomUUID();
        const newCell: NotebookCell = {
          cell_type: cell_type,
          id: newCellId,
          source: sourceToArray(new_source),
          metadata: {},
        };
        if (cell_type === "code") {
          newCell.outputs = [];
          newCell.execution_count = null;
        }

        if (cell_id) {
          const index = findCellIndex(cell_id);
          notebook.cells.splice(index + 1, 0, newCell);
          resultMessage = `Inserted new ${cell_type} cell ${newCellId} after ${cell_id}`;
        } else {
          notebook.cells.unshift(newCell);
          resultMessage = `Inserted new ${cell_type} cell ${newCellId} at beginning`;
        }
        break;
      }

      case "delete": {
        if (!cell_id) {
          throw new Error("cell_id is required for delete mode");
        }
        const index = findCellIndex(cell_id);
        notebook.cells.splice(index, 1);
        resultMessage = `Deleted cell ${cell_id}`;
        break;
      }

      default:
        throw new Error(`Unknown edit_mode: ${edit_mode}`);
    }

    const updatedContent = JSON.stringify(notebook, null, 1);
    await writeFile(notebook_path, updatedContent, "utf-8");

    return resultMessage;
  },
});
