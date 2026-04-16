---
name: deep-research
description: Run deeper web research with the Exa-backed web_search, code_search, and read_web_pages tools. Use this when a task needs query refinement, multiple sources, evidence gathering, and a synthesized answer with citations.
---

# Deep Research

Use this skill when the task is more than a single lookup: debugging from docs across several pages, comparing frameworks, reviewing multiple announcements, tracing implementation details in source code, or building a cited research summary.

## Available tools

- `web_search` for broad web discovery and current information
- `code_search` for docs, API references, GitHub, and implementation examples
- `read_web_pages` for expanding the best URLs into clean highlights, text, or summaries

## Default workflow

1. Start broad.
   - Use `web_search` for general framing or fresh information.
   - Use `code_search` when the question is mostly about documentation or source code.

2. Narrow quickly.
   - Rewrite the query based on what is missing.
   - Prefer several targeted searches over one giant vague query.
   - Use domain filters when official sources are obvious.

3. Prefer efficient extraction first.
   - Default to `contentMode: "highlights"`.
   - Switch to `read_web_pages` with `contentMode: "text"` only for the small set of URLs that matter most.

4. Cross-check.
   - Prefer official docs first.
   - Then use source code, release notes, issue threads, or secondary sources to confirm details.
   - Call out uncertainty instead of overclaiming.

5. Synthesize with evidence.
   - End with a concise answer.
   - Include source URLs.
   - Separate confirmed findings from inference.

## Heuristics

### For docs/API questions

- Start with `code_search` using `focus: "docs"`.
- If the first pass is noisy, add domains for the official docs site.
- Expand 1-3 promising pages with `read_web_pages`.

### For source-code or implementation questions

- Start with `code_search` using `focus: "source"`.
- If needed, follow with `focus: "mixed"` to pick up docs and blog posts.
- Expand the most relevant repositories or documentation pages with `read_web_pages`.

### For current events / announcements / recent changes

- Start with `web_search`.
- Consider `freshnessHours` when recency matters.
- Use `read_web_pages` on the most authoritative results.

## Output style

When reporting back:

- Lead with the direct answer.
- Then give a short list of findings.
- Then list sources as bullet points with URLs.
- If there are conflicting sources, say so explicitly.

## Example invocations

- `/skill:deep-research How does Exa deep search differ from normal search for coding-agent workflows?`
- `/skill:deep-research Find the best current docs and code examples for building a Pi extension with Exa-backed search.`
- `/skill:deep-research Investigate how a library handles retries, cancellation, and rate limits, using both docs and source.`
