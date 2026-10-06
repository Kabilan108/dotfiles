import { createHighlighterCore, type HighlighterCore } from "@shikijs/core";
import { createJavaScriptRegexEngine } from "@shikijs/engine-javascript";

export const LANGS = [
  "typescript", "tsx", "javascript", "jsx", "json", "jsonc", "python", "go", "rust", "nix", "lua",
  "shellscript", "fish", "toml", "yaml", "sql", "html", "css", "scss", "markdown", "dockerfile",
  "c", "java", "kotlin", "swift", "ruby", "graphql", "proto", "ini", "kdl", "xml", "qml", "r",
  "make", "cmake", "hcl", "zig", "diff",
];

export async function createHighlighter(): Promise<HighlighterCore> {
  return createHighlighterCore({
    themes: [import("@shikijs/themes/catppuccin-latte"), import("@shikijs/themes/catppuccin-mocha")],
    langs: [
      import("@shikijs/langs/typescript"), import("@shikijs/langs/tsx"), import("@shikijs/langs/javascript"),
      import("@shikijs/langs/jsx"), import("@shikijs/langs/json"), import("@shikijs/langs/jsonc"),
      import("@shikijs/langs/python"), import("@shikijs/langs/go"), import("@shikijs/langs/rust"),
      import("@shikijs/langs/nix"), import("@shikijs/langs/lua"), import("@shikijs/langs/shellscript"),
      import("@shikijs/langs/fish"), import("@shikijs/langs/toml"), import("@shikijs/langs/yaml"),
      import("@shikijs/langs/sql"), import("@shikijs/langs/html"), import("@shikijs/langs/css"),
      import("@shikijs/langs/scss"), import("@shikijs/langs/markdown"), import("@shikijs/langs/dockerfile"),
      import("@shikijs/langs/c"), import("@shikijs/langs/java"), import("@shikijs/langs/kotlin"),
      import("@shikijs/langs/swift"), import("@shikijs/langs/ruby"), import("@shikijs/langs/graphql"),
      import("@shikijs/langs/proto"), import("@shikijs/langs/ini"), import("@shikijs/langs/kdl"),
      import("@shikijs/langs/xml"), import("@shikijs/langs/qml"), import("@shikijs/langs/r"),
      import("@shikijs/langs/make"), import("@shikijs/langs/cmake"), import("@shikijs/langs/hcl"),
      import("@shikijs/langs/zig"), import("@shikijs/langs/diff"),
    ],
    engine: createJavaScriptRegexEngine({ forgiving: true }),
  });
}
