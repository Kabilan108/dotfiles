---
name: btca-local
description: Invoke this skill when the user says "use btca", "btca local", or asks to search/study a git repo through BTCA
---

# BTCA Local

BTCA Local, aka "The Better Context App Local" is a simple app defined as a skill file. The purpose of this app is to search git repos cloned onto this machine.

## the BTCA Search Workflow

<guidelines>
    <guideline>
        if the user includes a repo reference — a GitHub URL, an `owner/repo` slug, an SSH URL, or a local path — resolve and use that exact repo
    </guideline>
    <guideline>
        if the user doesn't include any specific links/repos they want you to use, do your best to guess based on the context provided
    </guideline>
    <guideline>
        always include links/citations in your answers explaining what you found. prefer GitHub blob links pinned to a commit hash for public repos; for local or vendored checkouts, cite file paths with line numbers and the checkout's commit hash
    </guideline>
    <guideline>
        include very clear and complete code snippets. don't leave out stuff like imports, that's important context
    </guideline>
    <guideline>
        when answering use lots of bulleted/numbered lists to keep things readable and clear
    </guideline>
    <guideline>
        respect explicit constraints like "read-only", "planning only", or "do not edit files"
    </guideline>
</guidelines>

<workflow>
    <step name="work dir setup">
        use ~/.btca/agent/sandbox for BTCA-managed clones. if the user points at an existing local checkout or the current project vendors the relevant repo, use that checkout instead and say which path/revision you used
    </step>
    <step name="load">
        if the repo is already in ~/.btca/agent/sandbox, fetch/update it — but don't switch branches if the checkout appears intentionally pinned or the user asked for a specific branch/tag/commit. otherwise clone it; clone the default branch unless the user asks for something else
    </step>
    <step name="search">
        search the repo for the information you need (rg, git grep, git log, file reads). record the commit hash you searched so citations stay reproducible. make sure to follow the guidelines
    </step>
</workflow>

<end_goal>
a clear, concise answer to the question with code examples
</end_goal>

## Startup Cases:

This skill can be invoked in a couple different ways, and your behavior should reflect that:

### user invoked without extra context/question

this is the "app startup" state, almost as if a terminal app was booted up.

Your job is to search the working directory ~/.btca/agent/sandbox at the top level, just to get a list of all the repos that have been previously cloned

Then you should simply output the following markdown (filling in the existing repos):

```md
# BTCA Local

_use your coding agent to search any git repo locally_

Previously searched:

- repo 1
- ...

Give me a question and the link to a git repo to get started!
(we can also clean out or pre-load some resources to this list...)
```

### you invoked because of user's prompt

in this case, your job is to answer/execute the users prompt faithfully, just while also using the btca search workflow when needed to better execute your task

### user invoked while also giving a prompt/questions

this one's simple, simply answer the users prompt with the btca search workflow
