# Example plugins

Three minimal plugins that pass validation and load in the workbench. They are
the starting points the `stillsuit-plugin` skill copies from; they are not in
the production registry.

| Directory | Kinds | Shows |
|---|---|---|
| `widget/` | bar-widget | the smallest plugin: one chip, context and outputId only |
| `widget-panel/` | bar-widget, panel | a chip that toggles a hosted panel; `selected` highlight |
| `service-widget-panel/` | service, bar-widget, panel | one global service owning state and a timer; per-output views |

Copy one into `src/plugins/builtin/<name>/` for a live plugin, or into
`~/.config/stillsuit/workbench/plugins/<name>/` to iterate in the workbench,
and change the manifest `id`.
