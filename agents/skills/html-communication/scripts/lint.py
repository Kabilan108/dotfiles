#!/usr/bin/env python3
"""Warn about readability and trust problems in an HTML artifact. Always exits 0 once the page is read."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path

MAX_PROSE_RUN = 300
MAX_WORDS_PER_EXHIBIT = 250
MIN_PROSE_FOR_RATIO = 500
MAX_PARAGRAPH = 60
MAX_CLAIM_WORDS = 16
MAX_CHILDREN = 5
MAX_DEPTH = 3
MAX_DECISIONS = 6
MAX_QUESTION_WORDS = 15
MAX_OPTION_NOTE_WORDS = 12
MAX_CODE_LINE = 100
MAX_PHONE_WIDTH = 480
MAX_TABLE_COLUMNS = 6

VOID = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "source",
    "track",
    "wbr",
}
HIDDEN = {"script", "style", "template", "noscript"}
EXHIBIT_TAGS = {
    "svg",
    "canvas",
    "table",
    "pre",
    "img",
    "video",
    "iframe",
    "figure",
    "picture",
}
PROSE_TAGS = {"p", "li", "dd", "blockquote", "summary"}
# Adapted from html-plan's pack.mjs (Thariq Shihipar, MIT):
# https://github.com/anthropics/claude-plugins-community/tree/main/html-plan
SECRET = re.compile(
    r"sk-ant-[A-Za-z0-9_-]{10,}|sk-[A-Za-z0-9]{32,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY"
    r"|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[abeprs]-[A-Za-z0-9-]{10,}"
    r"|AIza[0-9A-Za-z_-]{30,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\."
    r"|(?:password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token)[\"']?\s*[:=]\s*[\"'][^\"'\s$<{]{12,}[\"']",
    re.IGNORECASE,
)
SOURCE_SPEC = re.compile(r"^(?P<path>[^:]+):(?P<start>\d+)(?:-(?P<end>\d+))?$")
PRE_WRAP_RULE = re.compile(
    r"\bpre\b[^{}]*\{[^}]*white-space\s*:\s*(pre-wrap|break-spaces)"
)
GIT_REF = re.compile(r"^[A-Za-z0-9][\w./-]{0,99}$")
LANGUAGE_CLASS = re.compile(r"(?:^|\s)lang(?:uage)?-([\w+#-]+)", re.IGNORECASE)
PLAIN_LANGUAGES = {
    "text",
    "plaintext",
    "plain",
    "txt",
    "tree",
    "none",
    "output",
    "console-output",
}


def code_language(node: Node) -> str | None:
    match = LANGUAGE_CLASS.search(node.attrs.get("class", ""))
    if match:
        return match.group(1).lower()
    return node.attrs.get("data-lang") or None


@dataclass
class Node:
    tag: str
    attrs: dict[str, str]
    line: int
    parent: Node | None = None
    children: list[Node | str] = field(default_factory=list)

    def has(self, attr: str) -> bool:
        return attr in self.attrs

    def classes(self) -> set[str]:
        return set(self.attrs.get("class", "").split())

    def is_exhibit(self) -> bool:
        return self.tag in EXHIBIT_TAGS or self.has("data-exhibit")

    def is_claim(self) -> bool:
        return self.tag == "details" and "claim" in self.classes()

    def elements(self) -> list[Node]:
        return [c for c in self.children if isinstance(c, Node)]

    def walk(self):
        yield self
        for child in self.elements():
            yield from child.walk()

    def find_all(self, predicate) -> list[Node]:
        return [n for n in self.walk() if predicate(n)]

    def text(self, skip=None) -> str:
        parts: list[str] = []
        for child in self.children:
            if isinstance(child, str):
                parts.append(child)
            elif child.tag not in HIDDEN and not (skip and skip(child)):
                parts.append(child.text(skip))
        return re.sub(r"\s+", " ", " ".join(parts)).strip()

    def raw_text(self) -> str:
        return "".join(c if isinstance(c, str) else c.raw_text() for c in self.children)

    def ancestors(self):
        node = self.parent
        while node:
            yield node
            node = node.parent


class TreeBuilder(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node("#document", {}, 1)
        self.stack = [self.root]

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        node = Node(
            tag, {k: v or "" for k, v in attrs}, self.getpos()[0], self.stack[-1]
        )
        self.stack[-1].children.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        node = Node(
            tag, {k: v or "" for k, v in attrs}, self.getpos()[0], self.stack[-1]
        )
        self.stack[-1].children.append(node)

    def handle_endtag(self, tag: str) -> None:
        if any(n.tag == tag for n in self.stack[1:]):
            while self.stack[-1].tag != tag:
                self.stack.pop()
            self.stack.pop()

    def handle_data(self, data: str) -> None:
        self.stack[-1].children.append(data)


def words(text: str) -> int:
    return len(text.split())


class Linter:
    def __init__(self, path: Path, html: str, root: Path | None) -> None:
        self.path = path
        self.html = html
        self.root = root
        builder = TreeBuilder()
        builder.feed(html)
        self.doc = builder.root
        self.warnings: list[tuple[int, str]] = []

    def warn(self, line: int, message: str) -> None:
        self.warnings.append((line, message))

    def run(self) -> list[tuple[int, str]]:
        self.check_head()
        self.check_prose()
        self.check_freshness()
        self.check_decisions()
        self.check_charts()
        self.check_code()
        self.check_anchors()
        self.check_phone_width()
        self.check_secrets()
        if self.is_plan():
            self.check_plan()
        return sorted(self.warnings)

    def check_head(self) -> None:
        if not self.doc.find_all(lambda n: n.tag == "title" and n.text()):
            self.warn(
                1, "no <title>; it names the artifact in tabs and in the PageBin list"
            )
        if not self.doc.find_all(lambda n: n.tag == "h1"):
            self.warn(1, "no <h1>")

    def check_prose(self) -> None:
        body = next(iter(self.doc.find_all(lambda n: n.tag == "body")), self.doc)
        state = {
            "run": 0,
            "run_start": body.line,
            "max_run": 0,
            "max_line": body.line,
            "prose": 0,
            "exhibits": 0,
        }
        long_paragraphs: list[int] = []

        def end_run(line: int) -> None:
            if state["run"] > state["max_run"]:
                state["max_run"], state["max_line"] = state["run"], state["run_start"]
            state["run"], state["run_start"] = 0, line

        def visit(node: Node) -> None:
            if node.tag in HIDDEN:
                return
            if node.is_exhibit():
                state["exhibits"] += 1
                end_run(node.line)
                return
            if node.tag in PROSE_TAGS:
                count = words(
                    node.text(
                        skip=lambda n: (
                            n.is_exhibit() or n.tag in PROSE_TAGS or n.is_claim()
                        )
                    )
                )
                if count > MAX_PARAGRAPH:
                    long_paragraphs.append(node.line)
                if state["run"] == 0:
                    state["run_start"] = node.line
                state["run"] += count
                state["prose"] += count
            for child in node.elements():
                visit(child)

        visit(body)
        end_run(body.line)
        if state["max_run"] > MAX_PROSE_RUN:
            self.warn(
                state["max_line"],
                f"{state['max_run']} words of prose with no exhibit between them (aim for <= {MAX_PROSE_RUN}); open the stretch with an exhibit or fold depth into a collapsible section",
            )
        ratio = state["prose"] // max(state["exhibits"], 1)
        if state["prose"] >= MIN_PROSE_FOR_RATIO and ratio > MAX_WORDS_PER_EXHIBIT:
            self.warn(
                1,
                f"{state['prose']} words of prose for {state['exhibits']} exhibits, {ratio} per exhibit (aim for <= {MAX_WORDS_PER_EXHIBIT})",
            )
        if long_paragraphs:
            shown = ", ".join(str(n) for n in long_paragraphs[:6])
            self.warn(
                long_paragraphs[0],
                f"{len(long_paragraphs)} paragraph(s) over {MAX_PARAGRAPH} words (lines {shown}{', ...' if len(long_paragraphs) > 6 else ''})",
            )

    def check_freshness(self) -> None:
        if not self.doc.find_all(lambda n: n.has("data-freshness")):
            self.warn(
                1,
                "no data-freshness element: say when it was updated, what commit or data it reviewed, and what it supersedes",
            )

    def check_decisions(self) -> None:
        decisions = self.doc.find_all(lambda n: n.has("data-pb-decision"))
        seen: dict[str, int] = {}
        for decision in decisions:
            key = decision.attrs["data-pb-decision"]
            if not key:
                self.warn(decision.line, "data-pb-decision has no ID")
                continue
            if key in seen:
                self.warn(
                    decision.line,
                    f'decision "{key}" repeats the ID used on line {seen[key]}',
                )
            seen[key] = decision.line
            if decision.attrs.get("id") != key:
                self.warn(
                    decision.line,
                    f'decision "{key}": set id="{key}" so links and chat answers can cite it',
                )
            if key not in decision.text():
                self.warn(
                    decision.line,
                    f'decision "{key}": show the ID in the visible text so the user can answer in chat by ID',
                )
            question = next(
                iter(
                    decision.find_all(lambda n: n.tag in {"h2", "h3", "h4", "legend"})
                ),
                None,
            )
            if question is None:
                self.warn(decision.line, f'decision "{key}": no question heading')
            elif words(question.text()) > MAX_QUESTION_WORDS + 1:
                self.warn(
                    question.line,
                    f'decision "{key}": the question is {words(question.text())} words (aim for <= {MAX_QUESTION_WORDS}); move context to one sentence after it',
                )
            for control in decision.find_all(
                lambda n: n.tag in {"input", "textarea", "select"} and n.has("name")
            ):
                name = control.attrs["name"]
                if name != key and not name.startswith(f"{key}:"):
                    self.warn(
                        control.line,
                        f'control "{name}" in decision "{key}": name it "{key}" or "{key}:<suffix>"',
                    )
            for small in decision.find_all(lambda n: n.tag == "small"):
                if words(small.text()) > MAX_OPTION_NOTE_WORDS:
                    self.warn(
                        small.line,
                        f'decision "{key}": option note is {words(small.text())} words (aim for <= {MAX_OPTION_NOTE_WORDS})',
                    )
        if len(decisions) > MAX_DECISIONS:
            self.warn(
                decisions[MAX_DECISIONS].line,
                f"{len(decisions)} decisions; ask about the forks that change the outcome and default the rest",
            )
        groups: dict[str, list[Node]] = {}
        for radio in self.doc.find_all(
            lambda n: (
                n.tag == "input" and n.attrs.get("type") == "radio" and n.has("name")
            )
        ):
            groups.setdefault(radio.attrs["name"], []).append(radio)
        for name, radios in groups.items():
            checked = sum(1 for r in radios if r.has("checked"))
            if checked == 0:
                self.warn(
                    radios[0].line,
                    f'radio group "{name}" has no checked option; check your recommendation',
                )
            elif checked > 1:
                self.warn(
                    radios[0].line,
                    f'radio group "{name}" has {checked} checked options; check one recommendation',
                )

    def check_charts(self) -> None:
        for chart in self.doc.find_all(lambda n: n.has("data-chart")):
            caption = next(iter(chart.find_all(lambda n: n.tag == "figcaption")), None)
            if caption is None or not caption.text():
                self.warn(chart.line, "chart has no caption stating the claim it shows")

    def check_highlighting(self) -> None:
        unlabelled: list[int] = []
        unhighlighted: list[int] = []
        for code in self.doc.find_all(
            lambda n: n.tag == "code" and n.parent is not None and n.parent.tag == "pre"
        ):
            pre = code.parent
            assert pre is not None
            lang = code_language(code) or code_language(pre)
            in_excerpt = any(a.has("data-source") for a in pre.ancestors())
            if not lang and not (in_excerpt and pre.has("data-highlighted")):
                unlabelled.append(pre.line)
            elif (
                lang and lang not in PLAIN_LANGUAGES and not pre.has("data-highlighted")
            ):
                unhighlighted.append(pre.line)
        if unlabelled:
            self.warn(
                unlabelled[0],
                f'{len(unlabelled)} code block(s) with no language; add class="language-…" (language-text for trees and output)',
            )
        if unhighlighted:
            self.warn(
                unhighlighted[0],
                f"{len(unhighlighted)} code block(s) not highlighted; run scripts/highlight.mts on the page",
            )

    def check_code(self) -> None:
        self.check_highlighting()
        sources = self.doc.find_all(lambda n: n.has("data-source"))
        if sources and self.root is None:
            self.warn(
                sources[0].line,
                f"{len(sources)} code excerpt(s) not checked against their files; pass --root <repo>",
            )
            return
        for figure in sources:
            self.check_excerpt(figure)

    def check_excerpt(self, figure: Node) -> None:
        spec = figure.attrs["data-source"]
        match = SOURCE_SPEC.match(spec)
        if not match:
            self.warn(
                figure.line,
                f'data-source="{spec}" should look like path/to/file.ts:40-52',
            )
            return
        rel, start = match["path"], int(match["start"])
        end = int(match["end"] or start)
        assert self.root is not None
        target = (self.root / rel).resolve()
        if not target.is_relative_to(self.root.resolve()) or not target.is_file():
            self.warn(
                figure.line, f'data-source "{rel}" is not a file under {self.root}'
            )
            return
        pre = next(iter(figure.find_all(lambda n: n.tag == "pre")), None)
        if pre is None:
            self.warn(figure.line, f'data-source "{spec}" has no <pre> excerpt')
            return
        excerpt = normalize_code(pre.raw_text())
        commit = figure.attrs.get("data-commit", "")
        if commit:
            at_commit = git_show(self.root, commit, rel)
            if at_commit is None:
                self.warn(
                    figure.line,
                    f'data-commit "{commit}" does not hold {rel} in {self.root}',
                )
            elif excerpt != normalize_code(
                "\n".join(at_commit.splitlines()[start - 1 : end])
            ):
                self.warn(
                    figure.line,
                    f"excerpt does not match {rel}:{start}-{end} at {commit}; recopy the lines or fix the range",
                )
                return
        else:
            self.warn(figure.line, f'excerpt "{spec}" has no data-commit')
        lines = target.read_text(errors="replace").splitlines()
        if end > len(lines) or start < 1 or start > end:
            self.warn(
                figure.line,
                f"{rel} has {len(lines)} lines; the range {start}-{end} is outside it",
            )
        elif excerpt != normalize_code("\n".join(lines[start - 1 : end])):
            note = (
                "the file changed since that commit"
                if commit
                else "recopy the lines or fix the range"
            )
            self.warn(
                figure.line,
                f"excerpt differs from {rel}:{start}-{end} in the working tree; {note}",
            )

    def check_anchors(self) -> None:
        ids: dict[str, int] = {}
        for node in self.doc.walk():
            node_id = node.attrs.get("id")
            if node_id:
                if node_id in ids:
                    self.warn(
                        node.line,
                        f'duplicate id="{node_id}" (also line {ids[node_id]})',
                    )
                ids.setdefault(node_id, node.line)
        for link in self.doc.find_all(
            lambda n: n.tag == "a" and n.attrs.get("href", "").startswith("#")
        ):
            target = link.attrs["href"][1:]
            if target and target not in ids:
                self.warn(link.line, f'href="#{target}" points at no id')

    def check_phone_width(self) -> None:
        wide_blocks = []
        styles = " ".join(
            s.raw_text() for s in self.doc.find_all(lambda n: n.tag == "style")
        )
        page_wraps = bool(PRE_WRAP_RULE.search(styles))
        for pre in self.doc.find_all(lambda n: n.tag == "pre"):
            wraps = (
                page_wraps
                or "pre-wrap" in pre.attrs.get("style", "")
                or "wrap" in pre.classes()
            )
            if not wraps and any(
                len(line) > MAX_CODE_LINE for line in pre.raw_text().splitlines()
            ):
                wide_blocks.append(pre.line)
        if wide_blocks:
            self.warn(
                wide_blocks[0],
                f"{len(wide_blocks)} code block(s) with lines over {MAX_CODE_LINE} characters; reflow or wrap them for phones",
            )
        for svg in self.doc.find_all(lambda n: n.tag == "svg"):
            width = re.match(r"\d+", svg.attrs.get("width", ""))
            if (
                width
                and int(width.group()) > MAX_PHONE_WIDTH
                and not svg.has("viewbox")
            ):
                self.warn(
                    svg.line,
                    f"svg is {width.group()}px wide with no viewBox, so it cannot scale to a phone",
                )
        for table in self.doc.find_all(lambda n: n.tag == "table"):
            columns = max(
                (
                    len(row.find_all(lambda n: n.tag in {"td", "th"}))
                    for row in table.find_all(lambda n: n.tag == "tr")
                ),
                default=0,
            )
            scrolls = any(
                any("scroll" in c or "wrap" in c for c in a.classes())
                for a in table.ancestors()
            )
            if columns > MAX_TABLE_COLUMNS and not scrolls:
                self.warn(
                    table.line,
                    f"table has {columns} columns; put it in a horizontal scroll wrapper for phones",
                )

    def check_secrets(self) -> None:
        for number, line in enumerate(self.html.splitlines(), 1):
            if SECRET.search(line):
                self.warn(
                    number,
                    "looks like a credential or secret; remove it before publishing",
                )

    def is_plan(self) -> bool:
        return any(
            n.attrs.get("data-genre") == "plan"
            for n in self.doc.find_all(lambda n: n.tag in {"html", "body", "main"})
        )

    def check_plan(self) -> None:
        h1 = next(iter(self.doc.find_all(lambda n: n.tag == "h1")), None)
        if h1 is not None and (words(h1.text()) > 8 or h1.text().endswith(".")):
            self.warn(
                h1.line,
                "plan title is a sentence; name the change and the place in 3 to 7 words",
            )
        claims = self.doc.find_all(lambda n: n.is_claim())
        top = [c for c in claims if not any(a.is_claim() for a in c.ancestors())]
        if not top:
            self.warn(1, 'plan has no <details class="claim"> tree')
            return
        main_claims = [c for c in top if not c.has("data-aux")]
        if len(main_claims) > MAX_CHILDREN:
            self.warn(
                main_claims[MAX_CHILDREN].line,
                f"{len(main_claims)} top-level claims (at most {MAX_CHILDREN}, plus shared and scope)",
            )
        if not any(c.attrs.get("data-aux") == "scope" for c in top):
            self.warn(
                top[-1].line, 'no data-aux="scope" claim saying what is not changing'
            )
        for claim in claims:
            self.check_claim(claim)

    def check_claim(self, claim: Node) -> None:
        depth = 1 + sum(1 for a in claim.ancestors() if a.is_claim())
        summary = next((c for c in claim.elements() if c.tag == "summary"), None)
        aux = claim.has("data-aux")
        if summary is None or not summary.text():
            self.warn(claim.line, "claim has no <summary> sentence")
            return
        sentence = re.sub(r"^\s*\d+(\.\d+)*\s*", "", summary.text())
        if words(sentence) > MAX_CLAIM_WORDS:
            self.warn(
                summary.line,
                f"claim is {words(sentence)} words; one sentence that can be true or false, about 12 words",
            )
        if depth <= 2 and not aux and not re.search(r"[.?!]$", sentence):
            self.warn(
                summary.line,
                f'"{sentence[:40]}" reads as a heading; write a full sentence',
            )
        if depth > MAX_DEPTH:
            self.warn(
                claim.line,
                f"claim at level {depth}; three levels at most (what, how, where)",
            )
        children = [c for c in claim.elements() if c.is_claim()]
        if len(children) > MAX_CHILDREN:
            self.warn(
                children[MAX_CHILDREN].line,
                f"{len(children)} child claims; {MAX_CHILDREN} at most",
            )
        exhibit_count = own_exhibits(claim)
        if exhibit_count > 1 and not aux:
            self.warn(
                claim.line,
                f"claim has {exhibit_count} exhibits; one per claim, the rest become child claims",
            )
        if (
            exhibit_count == 0
            and not children
            and claim.attrs.get("data-aux") != "scope"
        ):
            self.warn(claim.line, "claim has no exhibit proving it")


def own_exhibits(node: Node) -> int:
    count = 0
    for child in node.elements():
        if child.is_claim() or child.tag == "summary" or child.has("data-pb-decision"):
            continue
        count += 1 if child.is_exhibit() else own_exhibits(child)
    return count


def normalize_code(text: str) -> str:
    lines = [line.rstrip() for line in text.replace("\t", "    ").splitlines()]
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()
    return "\n".join(lines)


def git_show(root: Path, ref: str, rel: str) -> str | None:
    if not GIT_REF.match(ref) or ".." in Path(rel).parts or rel.startswith(("/", "-")):
        return None
    try:
        return subprocess.run(
            ["git", "-C", str(root), "show", f"{ref}:{rel}"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        ).stdout
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        FileNotFoundError,
    ):
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("page", type=Path)
    parser.add_argument(
        "--root", type=Path, help="repository that data-source excerpts are cited from"
    )
    args = parser.parse_args()
    try:
        html = args.page.read_text(errors="replace")
    except OSError as error:
        print(f"lint: cannot read {args.page}: {error}", file=sys.stderr)
        return 2
    root = args.root.expanduser() if args.root else None
    warnings = Linter(args.page, html, root).run()
    for line, message in warnings:
        print(f"{args.page}:{line}: {message}")
    print(f"lint: {len(warnings)} warning(s)" if warnings else "lint: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
