# Example plugins

Three minimal plugins that pass validation and load in the workbench. They are
the starting points the `stillsuit-plugin` skill copies from; they are not in
the production registry.

| Directory | Kinds | Shows |
|---|---|---|
| `widget/` | bar-widget | the smallest plugin: one chip, context and outputId only |
| `widget-panel/` | bar-widget, panel | a chip that toggles a hosted panel; `selected` highlight |
| `service-widget-panel/` | service, bar-widget, panel | one global service owning state and a timer; per-output views |

Copy one into `~/.config/stillsuit/workbench/plugins/<name>/`, change the
manifest `id`, and start `stillsuit-workbench`.
