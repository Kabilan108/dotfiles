# Shared UI reference

`import Stillsuit.Ui as Ui`. Every component takes `required property var theme`
(pass `context.theme`). Full rules: `src/ui/README.md`; sources: `src/ui/*.qml`.

## Theme roles

Use these, never literal values.

```
theme.semantic.content.{primary,secondary,muted,disabled,inverse}
theme.semantic.status.{info,success,warning,danger}
theme.semantic.signal.{audio,microphone,brightness,charging,recording}
theme.semantic.intensity.{normal,elevated,high,critical}
theme.semantic.surface.{bar,panel,raised,overlay,hover,pressed,selected,danger}
theme.semantic.accent.{primary,hover,pressed,subtle,onAccent}
theme.semantic.outline.{subtle,default,strong,focus}
theme.component.bar.{clusterText,clusterActiveText,clusterHover,clusterActive,...}
theme.component.control.{background,hover,pressed,active,text,textDisabled,onActive,...}
theme.metrics.{spaceUnit,radiusSmall,radiusMedium,radiusLarge,barHeight,iconSmall,iconMedium,iconLarge,panelWidth,panelPadding,rowHeight}
theme.motion.{fast,normal,slow}
```

## Bar

```qml
Ui.ShellBarCluster {
    theme: context.theme
    iconName: "battery"            // catalog name; source: url for a brand image
    label: "74%"                   // optional text
    secondaryIconSource: ""        // second icon/label pair in the same click target
    secondaryLabel: ""
    badgeIconName: ""              // small overlay on the icon
    selected: /* panel open on this output */
    contentColor: theme.semantic.status.danger   // domain state; default follows selected
    tooltipText: "..."             // shown after 500 ms hover; default = accessible name
    accessibleName: "..."
    onClicked: /* toggle */
}
```

## Panel building blocks

```qml
Ui.ShellSurface { theme; kind: "panel" | "raised" | "osd"; selected; danger }   // container
Ui.ShellPanelHeader { theme; title; subtitle }                                  // default slot: trailing actions
Ui.ShellSectionLabel { theme; text }                                            // uppercase mono section title
Ui.ShellRow { theme; iconName; label; description; trailingIconName; trailingText; selected; danger; onClicked }
Ui.ShellScrollArea { theme; maximumHeight }                                     // capped, clipped, scrollbar
Ui.ShellButton { theme; label; iconName; active; destructive; compact; ghost; onClicked }
Ui.ShellToggle { theme; label; description; checked; onToggled: requested => owner applies then publishes }
Ui.ShellSlider { theme; label; from; to; value; stepSize; decimals; suffix; onMoved: value => owner applies }
Ui.ShellText { theme; text; role: "primary"|"secondary"|"muted"|...; sizeRole: "body"|"caption"|"label"|"section"|"heading"; monospace }
Ui.ShellIcon { theme; name; role; sizeRole: "small"|"medium"|"large"; source: url /* brand image, untinted */ }
Ui.ShellStatus { theme; label; iconName; role }                                 // compact inline status
Ui.ShellStateView { theme; mode: "empty"|"loading"|"error"; title; message; iconName; actionLabel; onActionRequested }
Ui.ShellEmptyRow { theme; iconName; text; error }                               // compact empty treatment
Ui.ShellBusyIndicator { theme; sizeRole; color }
```

Toggle and slider are owner-controlled: they emit the request and never write
their own value; the owner performs the change and publishes the accepted
state back. Set `reducedMotion` from `context.settings.values.reducedMotion`
when present.

## Icons

Catalog names (all tint from `role`): add, agent, audio, battery,
battery-alert, battery-charging, battery-level-0…6, battery-level-full,
battery-question, bluetooth, brightness, check, chevron-left, chevron-right,
circle, close, copy, cpu, danger, delete, edit, ethernet, expand-less,
expand-more, folder, forward-10, headphones, info, lock, memory, microphone,
more, network, notifications, pause, play, power, record, refresh,
replay-10, repeat, search, settings, shuffle, skip-next, skip-previous,
success, unlock, volume-down, volume-mute, volume-up, vpn, warning, wifi,
wifi-off. Unknown names render `circle`. `stillsuit-workbench open icon-gallery`
shows every one at every size and role.
