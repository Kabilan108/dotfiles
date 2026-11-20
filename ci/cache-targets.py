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
    cache-targets.py heavy [FLAKE]
        Print a JSON list of the pnames marked "# wait" in ci/cache-packages
        with a jacurutu output in neither the local store nor the cache, in
        file order. FLAKE (default: this checkout) names the commit to
        evaluate. It evaluates jacurutu only, so deploy-wait can run it there.

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
WAIT_HOST = "jacurutu"
CACHE = "https://kabilan108.cachix.org"
UPSTREAM = "https://cache.nixos.org"

UNGRAFTED_TOPLEVEL = """
host: (host.extendModules {
  modules = [ ({ lib, ... }: { system.replaceDependencies.replacements = lib.mkForce [ ]; }) ];
}).config.system.build.toplevel.drvPath
"""


def entries() -> list[tuple[str, str]]:
    """(pname, trailing comment) for each package line of ci/cache-packages."""
    found = []
    for line in (ROOT / "ci/cache-packages").read_text().splitlines():
        name, _, comment = line.partition("#")
        if name.strip():
            found.append((name.strip(), comment.strip()))
    return found


def packages() -> list[str]:
    return [name for name, _ in entries()]


def heavy_packages() -> list[str]:
    return [name for name, comment in entries() if comment == "wait"]


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


def closure(flake: str, host: str) -> list[str]:
    """The derivations and sources in host's ungrafted system closure."""
    top = run(
        "nix", "eval", "--raw",
        "--option", "allow-import-from-derivation", "true",
        "--apply", UNGRAFTED_TOPLEVEL,
        f"{flake}#nixosConfigurations.{host}",
    )
    return run("nix-store", "--query", "--requisites", top).split()


def find(
    names: list[str], flake: str, hosts: list[str]
) -> tuple[dict[str, dict[str, list[str]]], set[str]]:
    """Map each pname to {drv path: [output paths]} across hosts, and the
    pnames seen in any of their systems."""
    name_re = re.compile(
        r"/[a-z0-9]{32}-(?:" + "|".join(map(re.escape, names)) + r")-[^/]*\.drv$"
    )
    candidates: set[str] = set()
    for host in hosts:
        candidates.update(p for p in closure(flake, host) if name_re.search(p))

    found: dict[str, dict[str, list[str]]] = {name: {} for name in names}
    seen: set[str] = set()
    for path, drv in show(sorted(candidates)).items():
        pname = drv.get("env", {}).get("pname")
        outputs = drv.get("outputs", {}).values()
        if pname not in found or any("hash" in o or "hashAlgo" in o for o in outputs):
            continue
        seen.add(pname)
        outs = sorted(store_path(o["path"]) for o in outputs)
        if not all(cached(out, UPSTREAM) for out in outs):
            found[pname][path] = outs
    return found, seen


def targets(names: list[str]) -> dict[str, dict[str, list[str]]]:
    """Map each pname to {drv path: [output paths]} across all hosts."""
    require_atuin_ifd()
    found, seen = find(names, str(ROOT), HOSTS)
    missing = [name for name in names if name not in seen]
    if missing:
        sys.exit(f"cache-targets: not in any host system: {' '.join(missing)}")
    return found


def heavy(flake: str) -> list[str]:
    """The heavy pnames WAIT_HOST would have to build itself."""
    names = heavy_packages()
    found, _ = find(names, flake, [WAIT_HOST])
    outs = {name: sorted({o for paths in drvs.values() for o in paths}) for name, drvs in found.items()}
    every = sorted({o for paths in outs.values() for o in paths})
    absent = set()
    if every:
        absent = set(run("nix-store", "--check-validity", "--print-invalid", *every).split())
    return [name for name in names if any(o in absent and not cached(o) for o in outs[name])]


def cached(path: str, cache: str = CACHE) -> bool:
    url = f"{cache}/{Path(path).name[:32]}.narinfo"
    try:
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
        case ["heavy"]:
            print(json.dumps(heavy(str(ROOT))))
        case ["heavy", flake]:
            print(json.dumps(heavy(flake)))
        case _:
            sys.exit(__doc__)


if __name__ == "__main__":
    main()
