declare module "@mariozechner/pi-coding-agent" {
  export interface ExecResult {
    code: number;
    stdout: string;
    stderr: string;
    killed?: boolean;
  }

  export interface ExtensionThemeLike {
    fg(color: string, text: string): string;
    bold(text: string): string;
  }

  export interface ExtensionUIComponentLike {
    render(width: number): string[];
    handleInput?(data: string): void;
    invalidate(): void;
  }

  export interface ExtensionUI {
    notify(message: string, level: "info" | "warning" | "error"): void;
    setEditorText(text: string): void;
    custom<T>(
      factory: (
        tui: unknown,
        theme: ExtensionThemeLike,
        keybindings: unknown,
        done: (value: T) => void,
      ) => ExtensionUIComponentLike,
    ): Promise<T>;
  }

  export interface ExtensionContext {
    cwd: string;
    ui: ExtensionUI;
  }

  export interface ExtensionCommandContext extends ExtensionContext {}

  export interface ExtensionAPI {
    exec(command: string, args: string[], options?: { cwd?: string }): Promise<ExecResult>;
    registerCommand(
      name: string,
      options: {
        description?: string;
        handler: (args: string, ctx: ExtensionCommandContext) => Promise<void> | void;
      },
    ): void;
    on(event: string, handler: (...args: any[]) => Promise<void> | void): void;
  }
}
