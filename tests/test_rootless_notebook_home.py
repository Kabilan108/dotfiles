from __future__ import annotations

import os
import runpy
import subprocess
from pathlib import Path
from typing import Any

API: dict[str, Any] = runpy.run_path(
    str(Path(__file__).parents[1] / "bin/moberg-rootless-notebook-home")
)


def test_new_default_acl_preserves_masked_group_access(tmp_path: Path) -> None:
    directory = tmp_path / "home"
    directory.mkdir()
    subprocess.run(
        ["setfacl", "-m", "u:0:rwx,u:100999:rwx,g::rwx,m::r-x,o::---", str(directory)],
        check=True,
    )
    original = subprocess.check_output(["getfacl", "-cpn", str(directory)], text=True)
    # Names are inside namespace IDs; normalize the two test principals.
    original = original.replace("user:100999:", "user:1000:")
    updated = API["shared_acl"](original, directory=True)
    assert "default:group::r-x\n" in updated
    assert "default:mask::rwx\n" in updated
    subprocess.run(
        ["setfacl", "--set-file=-", str(directory)],
        input=updated,
        text=True,
        check=True,
    )
    child = directory / "child"
    child.write_text("shared\n")
    child_acl = subprocess.check_output(["getfacl", "-cpn", str(child)], text=True)
    assert "group::r-x" in child_acl
    assert "#effective:r--" in child_acl


def test_expanding_mask_does_not_revive_unrelated_principal(tmp_path: Path) -> None:
    file = tmp_path / "ordinary"
    file.write_text("data\n")
    subprocess.run(["setfacl", "-m", "u:234567:rwx,m::r--", str(file)], check=True)
    original = subprocess.check_output(["getfacl", "-cpn", str(file)], text=True)
    updated = API["shared_acl"](original, directory=False)
    subprocess.run(
        ["setfacl", "--set-file=-", str(file)], input=updated, text=True, check=True
    )
    acl = subprocess.check_output(["getfacl", "-cpn", str(file)], text=True)
    assert "user:234567:r--" in acl
    assert "mask::rw-" in acl


def test_repeat_preserves_explicit_private_permissions(tmp_path: Path) -> None:
    file = tmp_path / "private"
    file.write_text("private\n")
    subprocess.run(["setfacl", "-m", "u:0:rw,u:1000:rw", str(file)], check=True)
    file.chmod(0o600)
    original = subprocess.check_output(["getfacl", "-cpn", str(file)], text=True)
    updated = API["shared_acl"](original, directory=False)
    subprocess.run(
        ["setfacl", "--set-file=-", str(file)], input=updated, text=True, check=True
    )
    assert file.stat().st_mode & 0o777 == 0o600


def test_acl_mutation_uses_opened_inode_after_symlink_replacement(
    tmp_path: Path,
) -> None:
    file = tmp_path / "file"
    target = tmp_path / "outside"
    file.write_text("old\n")
    target.write_text("outside\n")
    target.chmod(0o600)
    descriptor = os.open(file, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        file.unlink()
        file.symlink_to(target)
        API["run"](
            ["setfacl", "-m", "u:100999:rw", f"/proc/self/fd/{descriptor}"],
            pass_fds=(descriptor,),
        )
        assert target.stat().st_mode & 0o777 == 0o600
        assert "user:100999:" not in subprocess.check_output(
            ["getfacl", "-cpn", str(target)], text=True
        )
    finally:
        os.close(descriptor)
