"""Find the derivations CI caches, straight from the host systems.

    cache-targets.py plan [EXPORT_DIR]
        Print {"packages": [...], "drvs": {pname: [...]}}: the pnames in
        ci/cache-packages with an output missing from the cache, in file
        order, and each one's derivation paths. With EXPORT_DIR, also copy
        those derivations and their closures into a binary cache there.
    cache-targets.py import PNAME CACHE_DIR DRV...
        Copy the derivations DRV and their closures from the binary cache at
        CACHE_DIR into the store, then check that each one builds PNAME.
    cache-targets.py drvs PNAME
        Print PNAME's derivation paths, one per line.

Reading the derivations out of each host's system closure means CI builds
exactly what the hosts would, and nothing they don't use.
"""

import json
import re
import shlex
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOSTS = ["sietch", "jacurutu"]
CACHE = "https://kabilan108.cachix.org"
UPSTREAM = "https://cache.nixos.org"

# A host's system before system.replaceDependencies grafts it. The graft
# rewrites built outputs, not derivations, so this closure holds the same
# package builds the host uses. Evaluating the grafted toplevel needs
# import-from-derivation of the whole system closure, which would build every
# package during the plan step. IFD stays off so that any other IFD fails the
# eval at once instead of building inside it.
#
# Temporary exception: Atuin's flake picks its Rust toolchain with fenix's
# fromToolchainFile, which downloads channel-rust-<version>.toml and reads it
# during eval. Until upstream pins the manifest as a flake input
# (fromManifestFile, no IFD), the plan step evaluates with IFD on, and any
# other IFD would build inside it too. require_atuin_ifd() fails the plan once
# the locked Atuin evaluates without IFD; then delete it and this paragraph.
UNGRAFTED_TOPLEVEL = """
host: (host.extendModules {
  modules = [ ({ lib, ... }: { system.replaceDependencies.replacements = lib.mkForce [ ]; }) ];
}).config.system.build.toplevel.drvPath
"""


def packages() -> list[str]:
    lines = (ROOT / "ci/cache-packages").read_text().splitlines()
    return [line.strip() for line in lines if line.strip() and not line.startswith("#")]


def run(*cmd: str) -> str:
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f"cache-targets: {shlex.join(cmd)} exited {proc.returncode}:\n{proc.stderr}")
    return proc.stdout


def store_path(path: str) -> str:
    return path if path.startswith("/nix/store/") else f"/nix/store/{path}"


def show(drvs: list[str]) -> dict[str, dict]:
    """`nix derivation show`, keyed by full store path, in either JSON format."""
    out: dict[str, dict] = {}
    for i in range(0, len(drvs), 200):
        shown = json.loads(run("nix", "derivation", "show", *drvs[i : i + 200]))
        for path, drv in shown.get("derivations", shown).items():
            out[store_path(path)] = drv
    return out


def path_info(paths: list[str]) -> dict[str, dict]:
    """`nix path-info --json` of paths and their closures, keyed by full store path."""
    shown = json.loads(run("nix", "path-info", "--json", "--recursive", *paths))
    return {store_path(path): info for path, info in shown.get("info", shown).items()}


def export(drvs: list[str], dest: Path) -> None:
    """Copy drvs and their closures into a binary cache at dest.

    The import checks each path against its content address. A path without
    one would need a signature instead, and CI has no key to sign it with.
    """
    unaddressed = sorted(path for path, info in path_info(drvs).items() if not info.get("ca"))
    if unaddressed:
        sys.exit("cache-targets: not content-addressed: " + " ".join(unaddressed))
    run("nix", "copy", "--to", f"file://{dest.resolve()}?compression=zstd", *drvs)


DRV_PATH = re.compile(r"/nix/store/[a-z0-9]{32}-[^/]+\.drv")


def import_drvs(name: str, cache: Path, drvs: list[str]) -> None:
    """Copy drvs from the binary cache and refuse any that don't build name.

    Without --no-check-sigs, the store checks every copied path's content
    against its content address.
    """
    bad = [drv for drv in drvs if not DRV_PATH.fullmatch(drv)]
    if not drvs or bad:
        sys.exit(f"cache-targets: expected derivation paths for {name}, got: {' '.join(bad)}")
    run("nix", "copy", "--from", f"file://{cache.resolve()}", *drvs)
    shown = show(drvs)
    for path in drvs:
        drv = shown[path]
        pname = drv.get("env", {}).get("pname")
        if pname != name or any("hash" in o or "hashAlgo" in o for o in drv["outputs"].values()):
            sys.exit(f"cache-targets: {path} is not a build of {name}")


def require_atuin_ifd() -> None:
    lock = json.loads((ROOT / "flake.lock").read_text())
    locked = lock["nodes"][lock["nodes"]["root"]["inputs"]["atuin"]]["locked"]
    ref = f"github:{locked['owner']}/{locked['repo']}/{locked['rev']}"
    proc = subprocess.run(
        [
            "nix", "eval", "--raw",
            "--option", "allow-import-from-derivation", "false",
            f"{ref}#packages.x86_64-linux.default.drvPath",
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode == 0:
        sys.exit(
            f"cache-targets: {ref} now evaluates without IFD. Remove require_atuin_ifd() "
            "and evaluate the hosts with allow-import-from-derivation false again."
        )
    if "allow-import-from-derivation" not in proc.stderr:
        sys.exit(f"cache-targets: evaluating {ref} failed:\n{proc.stderr}")


def targets(names: list[str]) -> dict[str, dict[str, list[str]]]:
    """Map each pname to {drv path: [output paths]} across all hosts."""
    name_re = re.compile(
        r"/[a-z0-9]{32}-(?:" + "|".join(map(re.escape, names)) + r")-[^/]*\.drv$"
    )
    require_atuin_ifd()
    candidates: set[str] = set()
    for host in HOSTS:
        top = run(
            "nix", "eval", "--raw",
            "--option", "allow-import-from-derivation", "true",
            "--apply", UNGRAFTED_TOPLEVEL,
            f"{ROOT}#nixosConfigurations.{host}",
        )
        closure = run("nix-store", "--query", "--requisites", top).split()
        candidates.update(p for p in closure if name_re.search(p))

    found: dict[str, dict[str, list[str]]] = {name: {} for name in names}
    seen: set[str] = set()
    for path, drv in show(sorted(candidates)).items():
        pname = drv.get("env", {}).get("pname")
        outputs = drv.get("outputs", {}).values()
        if pname not in found or any("hash" in o or "hashAlgo" in o for o in outputs):
            continue
        seen.add(pname)
        outs = sorted(store_path(o["path"]) for o in outputs)
        # Also skips nixpkgs builds of the same pname pulled in elsewhere.
        if not all(cached(out, UPSTREAM) for out in outs):
            found[pname][path] = outs

    missing = [name for name in names if name not in seen]
    if missing:
        sys.exit(f"cache-targets: not in any host system: {' '.join(missing)}")
    return found


def cached(path: str, cache: str = CACHE) -> bool:
    url = f"{cache}/{Path(path).name[:32]}.narinfo"
    try:
        # Cachix refuses urllib's default User-Agent.
        request = urllib.request.Request(
            url, method="HEAD", headers={"User-Agent": "dotfiles-cache-targets"}
        )
        with urllib.request.urlopen(request, timeout=30):
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


def main() -> None:
    match sys.argv[1:]:
        case ["plan", *export_dir] if len(export_dir) <= 1:
            found = targets(packages())
            todo = [
                name
                for name, drvs in found.items()
                if drvs and not all(cached(out) for outs in drvs.values() for out in outs)
            ]
            planned = {name: sorted(found[name]) for name in todo}
            if export_dir and todo:
                export(sorted(d for ds in planned.values() for d in ds), Path(export_dir[0]))
            print(json.dumps({"packages": todo, "drvs": planned}))
        case ["import", name, cache, *drvs] if name in packages():
            import_drvs(name, Path(cache), drvs)
        case ["drvs", name] if name in packages():
            print("\n".join(targets([name])[name]))
        case _:
            sys.exit(__doc__)


if __name__ == "__main__":
    main()
