# Stillsuit Home Manager module notes

- Keep `pkgs.coreutils` next to `pkgs.wl-clipboard` in the shell's runtime inputs, and change the list in both `options.nix` (the `package` default) and `service.nix` (`exactRuntimeInputs`) together. `wl-copy` and `wl-paste` exec `cat` to move clipboard data, and the unit's PATH holds nothing but these inputs, so a tool that shells out to an undeclared program fails at runtime, not at build time.
- Assign `stylix.base16Scheme` an attrset in `theme.nix`, never a `writeText` path. Stylix accepts a realized YAML path or a parsed scheme, and a derivation is not realized while the module graph is evaluated, so Stylix would read its store path as a scalar string instead of YAML.
