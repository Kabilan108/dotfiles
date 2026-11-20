# ci notes

- Evaluate hosts through `UNGRAFTED_TOPLEVEL` in `cache-targets.py`, never the plain toplevel. Hosts apply system.replaceDependencies, which rewrites built outputs and not derivations, so the ungrafted closure holds the same package builds; evaluating the grafted toplevel needs import-from-derivation (IFD) of the whole system closure and would build every package inside the plan step.
- Treat the IFD-enabled eval in `closure` as temporary. Atuin's flake picks its Rust toolchain with fenix's fromToolchainFile, which downloads the channel manifest and reads it during eval. Until upstream pins the manifest as a flake input (fromManifestFile), any other IFD in a host closure also builds inside the plan step without failing. When `require_atuin_ifd` starts failing the plan, delete it and pass allow-import-from-derivation false again.
- Keep an explicit User-Agent on the narinfo request in `cached`. Cachix refuses urllib's default one.
