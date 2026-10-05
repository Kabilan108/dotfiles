"""Reject a replaceable system Docker data path before starting the daemon."""

import stat
from pathlib import Path


def verify_storage(root: Path = Path("/")) -> None:
    for relative in (".", "vault", "vault/userdata", "vault/userdata/docker"):
        path = root / relative
        metadata = path.lstat()
        if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0:
            raise RuntimeError(f"system Docker requires a real root-owned directory: {path}")
        if relative in {"vault", "vault/userdata"}:
            if not metadata.st_mode & stat.S_ISVTX:
                raise RuntimeError(f"system Docker requires sticky protection: {path}")
        elif metadata.st_mode & 0o022:
            # The group class also represents the effective POSIX ACL mask.
            raise RuntimeError(f"system Docker rejects non-root write access: {path}")
    if not (root / "vault").is_mount():
        raise RuntimeError("system Docker requires the mounted vault filesystem")


if __name__ == "__main__":
    verify_storage()
