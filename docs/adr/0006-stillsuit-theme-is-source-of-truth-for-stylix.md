---
paths:
  - modules/home/stillsuit/theme.nix
  - packages/stillsuit-shell/themes/compile.nix
  - packages/stillsuit-shell/themes/from-base16.nix
---

# Stillsuit's theme record is the source of truth and Stylix gets a one-way Base16 projection

Stillsuit's theme is a rich record: neutral and chromatic ramps compiled into semantic and component roles, which every plugin reads. Stylix and its consumers understand only a 16-colour Base16 scheme. We author the rich record and derive `stylix.base16Scheme` from it, instead of authoring Base16 in Stylix and deriving Stillsuit's theme, because 16 colours cannot carry the ramps and roles and the derivation would have to invent them.

## Consequences

Stylix colours never feed back into Stillsuit. An existing Base16 scheme enters only through `packages/stillsuit-shell/themes/from-base16.nix`, an explicit adapter that fills the missing detail from a baseline, so a theme authored as Base16 has less detail than a native one.
