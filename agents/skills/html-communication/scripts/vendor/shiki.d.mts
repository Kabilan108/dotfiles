export interface ThemedToken {
  content: string;
  htmlStyle?: Record<string, string>;
}

export interface TokensResult {
  tokens: ThemedToken[][];
  rootStyle?: string;
}

export interface Highlighter {
  codeToTokens(
    code: string,
    options: { lang: string; themes: { light: string; dark: string }; defaultColor: false },
  ): TokensResult;
  getLoadedLanguages(): string[];
}

export declare const LANGS: string[];
export declare function createHighlighter(): Promise<Highlighter>;
