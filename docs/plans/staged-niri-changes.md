# Staged Niri changes

## Agent panel

Lane C does not apply this snippet. The orchestrator should add the exact rule
and binding to `home/desktop/wayland/compositors/niri/config.kdl`, then run
`niri validate` before merging the integration:

```kdl
window-rule {
    match app-id=r#"^io\.stillsuit\.AgentPanel$"#
    open-floating true
    default-column-width { proportion 0.72; }
    default-window-height { proportion 0.72; }
}

binds {
    Mod+Grave hotkey-overlay-title="Toggle Agent Panel" { spawn "stillsuit-agent-panel" "toggle"; }
}
```

If the existing `binds` block receives the binding, copy only the
`Mod+Grave` line rather than nesting another `binds` block. The helper focuses
an existing matching window on open. Niri places a new floating window on the
currently focused output.
