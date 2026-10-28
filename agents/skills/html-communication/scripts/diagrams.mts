// Renders <pre><code class="language-mermaid"> blocks with Pele, in place. Safe to rerun.
// Usage: node diagrams.mts page.html [more.html ...] [--cdn]
// Default: copies the vendored Pele build to <page dir>/pele/ for `pagebin publish --assets <page dir>/pele`.
// --cdn: loads the same pinned version from jsDelivr instead, for an HTML page shown in a thread.

import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const VENDOR = join(dirname(fileURLToPath(import.meta.url)), "vendor", "pele");
const VERSION = readFileSync(join(VENDOR, "VERSION"), "utf8").trim();
const MERMAID_BLOCK = /<pre\b[^>]*>\s*<code\b[^>]*\bclass\s*=\s*["'][^"']*\blanguage-mermaid\b/gi;
const INJECTED = /[ \t]*<(style|script)\b[^>]*\bdata-pele\b[^>]*>[\s\S]*?<\/\1>\n?/gi;

// Diagram colours follow whatever background and text colour the page has where each diagram sits.
// Page CSS can still set any --pele-* variable on .pele-diagram, since these rules have zero specificity.
const CSS = `:where(.pele-diagram){--pele-muted:color-mix(in oklab,var(--pele-fg) 62%,var(--pele-bg));--pele-line:color-mix(in oklab,var(--pele-fg) 55%,var(--pele-bg));--pele-surface:color-mix(in oklab,var(--pele-fg) 7%,var(--pele-bg));--pele-surface-alt:color-mix(in oklab,var(--pele-fg) 3.5%,var(--pele-bg));--pele-border:color-mix(in oklab,var(--pele-fg) 26%,var(--pele-bg));margin:8px 0}
.pele-source>summary{cursor:pointer;font-size:.85em;opacity:.7}`;

const MOUNT = `(() => {
  const auto = document.createElement("style");
  document.head.append(auto);
  const boxes = [];
  for (const code of document.querySelectorAll("pre > code.language-mermaid")) {
    const pre = code.parentElement;
    if (pre.closest(".pele-source")) continue;
    const box = document.createElement("div");
    box.className = "pele-diagram";
    box.dataset.peleN = String(boxes.length);
    const source = document.createElement("details");
    source.className = "pele-source";
    source.innerHTML = "<summary>Mermaid source</summary>";
    pre.replaceWith(box, source);
    source.append(pre);
    boxes.push([box, code.textContent]);
  }
  const opaque = (c) => c && !/^(transparent|rgba\\(.*,\\s*0\\))$/.test(c);
  const paint = () => {
    auto.textContent = boxes.map(([box]) => {
      let node = box, bg;
      while (node && !opaque(bg = getComputedStyle(node).backgroundColor)) node = node.parentElement;
      return \`:where(.pele-diagram[data-pele-n="\${box.dataset.peleN}"]){--pele-bg:\${opaque(bg) ? bg : "#fff"};--pele-fg:\${getComputedStyle(box).color}}\`;
    }).join("\\n");
  };
  paint();
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", paint);
  const themes = new MutationObserver((records) => {
    if (records.some((r) => r.target !== auto && r.target.parentNode !== auto)) paint();
  });
  const toggles = { attributes: true, attributeFilter: ["class", "data-theme", "style"] };
  themes.observe(document.documentElement, toggles);
  themes.observe(document.body, toggles);
  themes.observe(document.head, { childList: true, characterData: true, subtree: true });
  for (const [box, text] of boxes) pele.mount(box, text, { onError: (e) => console.error("pele:", e && e.message) });
})();`;

function loader(cdn: boolean): string {
  const src = cdn ? `https://cdn.jsdelivr.net/npm/pele@${VERSION}/dist/pele.global.js` : "pele/pele.global.js";
  return `<style data-pele>\n${CSS}\n</style>\n<script data-pele src="${src}" charset="utf-8"></script>\n<script data-pele>\n${MOUNT}\n</script>\n`;
}

function main(): number {
  const args = process.argv.slice(2);
  const cdn = args.includes("--cdn");
  const files = args.filter((a) => a !== "--cdn");
  if (!files.length || files.includes("-h") || files.includes("--help")) {
    console.error("usage: node diagrams.mts page.html [more.html ...] [--cdn]");
    return files.includes("-h") || files.includes("--help") ? 0 : 2;
  }
  let failed = false;
  for (const file of files) {
    let html: string;
    try {
      html = readFileSync(file, "utf8");
    } catch (error) {
      console.error(`diagrams: cannot read ${file}: ${(error as Error).message}`);
      failed = true;
      continue;
    }
    const count = html.match(MERMAID_BLOCK)?.length ?? 0;
    let output = html.replace(INJECTED, "");
    if (count) {
      output = /<\/body>/i.test(output) ? output.replace(/<\/body>/i, `${loader(cdn)}</body>`) : output + loader(cdn);
    }
    if (output !== html) writeFileSync(file, output);
    if (count && !cdn) {
      const assets = join(dirname(resolve(file)), "pele");
      mkdirSync(assets, { recursive: true });
      copyFileSync(join(VENDOR, "pele.global.js"), join(assets, "pele.global.js"));
      console.error(`${file}: ${count} diagram(s), Pele ${VERSION}; publish with --assets ${assets}`);
    } else {
      console.error(`${file}: ${count} diagram(s)${count ? `, Pele ${VERSION} from jsDelivr` : ""}`);
    }
  }
  return failed ? 1 : 0;
}

process.exitCode = main();
