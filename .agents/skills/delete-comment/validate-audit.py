import json
import sys
from pathlib import Path

CATEGORIES = {"tautology", "stale", "excuse", "reason", "keep"}
HOMES = {"code", "test", "note", "adr"}


def problems(blocks_path: Path, audit_path: Path, drafts: Path) -> list[str]:
    wanted = {block["id"] for block in json.loads(blocks_path.read_text())}
    audit = json.loads(audit_path.read_text())
    issues = {issue["key"] for issue in audit.get("issues", [])}
    itemised = {
        cid
        for item in audit.get("code_items", []) + audit.get("test_items", [])
        for cid in item.get("ids", [])
    }
    found: list[str] = []
    seen: dict[str, dict] = {}
    for comment in audit["comments"]:
        cid, category = comment["id"], comment["category"]
        if cid in seen:
            found.append(f"duplicate {cid}")
        seen[cid] = comment
        if category not in CATEGORIES:
            found.append(f"unknown category {category!r} for {cid}")
        if category == "excuse" and comment.get("issue") not in issues:
            found.append(f"excuse without an issue: {cid}")
        if category == "keep" and not comment.get("reason"):
            found.append(f"keep without a reason: {cid}")
        if category != "reason":
            continue
        home, target = comment.get("home"), comment.get("target", "")
        if home not in HOMES:
            found.append(f"reason without a valid home: {cid}")
        elif home in {"code", "test"} and cid not in itemised:
            found.append(f"{home} home without an item: {cid}")
        elif home == "note" and not (drafts / "notes" / target).is_file():
            found.append(f"note draft missing for {cid}: {target}")
        elif home == "adr" and not (drafts / target).is_file():
            found.append(f"ADR draft missing for {cid}: {target}")
    listed = {cid for cid, comment in seen.items() if not comment.get("embedded")}
    found += [f"missing {cid}" for cid in sorted(wanted - listed)]
    found += [f"not in the blocks file: {cid}" for cid in sorted(listed - wanted)]
    found += [
        f"issue needs a title and body: {issue['key']}"
        for issue in audit.get("issues", [])
        if not issue.get("title") or not issue.get("body")
    ]
    return found


def main() -> int:
    if len(sys.argv) != 4:
        sys.exit("usage: validate-audit.py BLOCKS_JSON AUDIT_JSON DRAFTS_DIR")
    blocks, audit, drafts = (Path(arg) for arg in sys.argv[1:])
    found = problems(blocks, audit, drafts)
    if found:
        print("\n".join(found))
        return 1
    comments = json.loads(audit.read_text())["comments"]
    print(f"OK {len(comments)} comments")
    return 0


if __name__ == "__main__":
    sys.exit(main())
