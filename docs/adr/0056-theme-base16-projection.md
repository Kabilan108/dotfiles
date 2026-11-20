# Stillsuit derives a one-way Base16 projection for Stylix

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Stillsuit's theme is a rich record: neutral and chromatic ramps compiled into semantic and component roles. Stylix and its consumers only understand a 16-color Base16 scheme. Stylix accepts either a realized YAML path or an already-parsed scheme. A `writeText` derivation is not realized while the module graph is evaluated, so Stylix would parse its store path as a scalar string instead of as YAML.

## Decision

- `theme.nix` builds `base16Projection` as a plain attrset from the neutral ramp and assigns it to `stylix.base16Scheme`.
- The projection is one-way. Stillsuit reads its own semantic record; Stylix consumers receive only the 16 projected colors.
- Importing an existing Base16 scheme goes through `themes/from-base16.nix`, an explicit, lossy adapter. Rich themes skip it and supply their own neutral and chromatic ramps to `compile.nix`.

## Consequences

Stylix colors cannot feed back into Stillsuit. A theme authored as Base16 loses detail that a native rich theme keeps. Passing a derivation path to `stylix.base16Scheme` in place of the attrset would break evaluation-time parsing.

## Where

- `modules/home/stillsuit/theme.nix` (`base16Projection`, `stylix.base16Scheme`)
- `packages/stillsuit-shell/themes/from-base16.nix`
- `packages/stillsuit-shell/themes/compile.nix`
