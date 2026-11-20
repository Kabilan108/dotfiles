import json
import sys
from pathlib import Path

CATEGORIES = {"tautology", "stale", "excuse", "decision", "keep"}


def problems(blocks_path: Path, audit_path: Path, adr_dir: Path) -> list[str]:
    wanted = {block["id"] for block in json.loads(blocks_path.read_text())}
    audit = json.loads(audit_path.read_text())
    issues = {issue["key"] for issue in audit.get("issues", [])}
    adrs = {adr["slug"] for adr in audit.get("adrs", [])}
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
        if category == "decision" and comment.get("adr") not in adrs and not comment.get("documented_in"):
            found.append(f"decision without an ADR or documented_in: {cid}")
        if category == "keep" and not comment.get("reason"):
            found.append(f"keep without a reason: {cid}")
    listed = {cid for cid, comment in seen.items() if not comment.get("embedded")}
    found += [f"missing {cid}" for cid in sorted(wanted - listed)]
    found += [f"not in the blocks file: {cid}" for cid in sorted(listed - wanted)]
    found += [f"ADR draft missing: {slug}" for slug in sorted(adrs) if not (adr_dir / f"{slug}.md").exists()]
    found += [
        f"issue needs a title and body: {issue['key']}"
        for issue in audit.get("issues", [])
        if not issue.get("title") or not issue.get("body")
    ]
    return found


def main() -> int:
    if len(sys.argv) != 4:
        sys.exit("usage: validate-audit.py BLOCKS_JSON AUDIT_JSON ADR_DIR")
    blocks, audit, adr_dir = (Path(arg) for arg in sys.argv[1:])
    found = problems(blocks, audit, adr_dir)
    if found:
        print("\n".join(found))
        return 1
    comments = json.loads(audit.read_text())["comments"]
    print(f"OK {len(comments)} comments")
    return 0


if __name__ == "__main__":
    sys.exit(main())
