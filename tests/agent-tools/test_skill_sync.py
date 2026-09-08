import os
import subprocess
import tempfile
from pathlib import Path

script = Path(__file__).resolve().parents[2] / "bin/sync-agent-skills"
with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    agents = root / "agents"
    for name in ["niri-computer-use", "keep"]:
        p = agents / "skills" / name
        p.mkdir(parents=True)
        (p / "SKILL.md").write_text("test")
    for agent in ["claude", "codex", "opencode"]:
        (agents / agent / "skills").mkdir(parents=True)
    env = {**os.environ, "DOTFILES_DIR": str(root)}

    def run(*args: str, code: int = 0) -> None:
        p = subprocess.run(
            [str(script), *args], env=env, capture_output=True, text=True, check=False
        )
        assert p.returncode == code, p.stdout + p.stderr

    run("--host", "jacurtu", code=1)
    assert not list((agents / "codex/skills").iterdir())
    empty = agents / "skills/empty"
    empty.mkdir()
    (agents / "codex/skills/empty").symlink_to(empty)
    run("--host", "jacurutu", "--dry-run")
    assert (agents / "codex/skills/empty").is_symlink()
    (agents / "codex/skills/empty").unlink()

    assert not list((agents / "codex/skills").iterdir())
    run("--host", "jacurutu")
    assert (agents / "codex/skills/niri-computer-use").is_symlink()
    assert not (agents / "codex/skills/empty").exists()
    (agents / "codex/skills/empty").symlink_to(empty)
    run("--host", "jacurutu")
    assert not (agents / "codex/skills/empty").is_symlink()
    (agents / "codex/skills/foreign").symlink_to(root / "foreign")
    run("--host", "sietch")
    assert not (agents / "codex/skills/niri-computer-use").is_symlink()
    assert (agents / "codex/skills/foreign").is_symlink()
    (agents / "codex/skills/keep").unlink()
    (agents / "codex/skills/keep").symlink_to(root / "foreign")
    run("--host", "jacurutu", code=1)
    assert (agents / "codex/skills/keep").readlink() == root / "foreign"
print("Skill sync: dry-run, host filtering, and foreign-link protection PASS")
