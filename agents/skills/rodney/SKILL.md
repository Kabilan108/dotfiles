---
name: rodney
description: Browser automation with persistent Chrome via CLI commands. Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include "go to [url]", "click on", "fill out the form", "take a screenshot", "scrape", "automate", "test the website", "log into", or any browser interaction request.
---

# Rodney Browser Automation

CLI tool that drives a persistent headless Chrome instance. Each command connects to the running Chrome via WebSocket, performs an action, and disconnects. Tabs and page state persist between commands.

## Session Lifecycle

```bash
# Check if Chrome is already running
rodney status

# Start Chrome (headless by default)
rodney start
rodney start --show          # Visible browser window
rodney start --local         # Project-scoped session (./.rodney/)

# Connect to existing Chrome on a remote debug port
rodney connect host:9222

# Stop Chrome and clean up
rodney stop
```

Use `--local` for project-isolated sessions (state in `./.rodney/`). Add `.rodney/` to `.gitignore`. Auto-detection: if `./.rodney/state.json` exists, Rodney uses it; otherwise falls back to global `~/.rodney/`.

## Core Workflow

### Navigate

```bash
rodney open https://example.com    # Navigate (http:// added if omitted)
rodney back                        # History back
rodney forward                     # History forward
rodney reload                      # Reload (--hard to bypass cache)
```

### Interact with Elements

```bash
rodney click "button#submit"       # Click element
rodney input "#search" "query"     # Type into input
rodney clear "#search"             # Clear input
rodney select "#dropdown" "value"  # Select dropdown option
rodney submit "form#login"         # Submit form
rodney hover ".menu-item"          # Hover over element
rodney focus "#email"              # Focus element
rodney file "#upload" photo.png    # Set file on file input
```

### Extract Information

```bash
rodney url                         # Current URL
rodney title                       # Page title
rodney text "h1"                   # Text content of element
rodney html "div.content"          # Outer HTML of element
rodney html                        # Full page HTML
rodney attr "a#link" href          # Attribute value
rodney pdf output.pdf              # Save page as PDF
```

### Run JavaScript

```bash
rodney js document.title
rodney js 'document.querySelector("h1").textContent'
rodney js '[1,2,3].map(x => x * 2)'    # Returns pretty-printed JSON
```

Expressions are wrapped in `() => { return (expr); }` automatically.

### Wait for Conditions

```bash
rodney wait ".loaded"              # Element appears and is visible
rodney waitload                    # Page load event
rodney waitstable                  # DOM stops changing
rodney waitidle                    # Network idle
rodney sleep 2.5                   # Sleep N seconds
```

### Screenshots

```bash
rodney screenshot                          # Save as screenshot.png
rodney screenshot page.png                 # Save to specific file
rodney screenshot -w 1280 -h 720 out.png   # Set viewport size
rodney screenshot-el ".chart" chart.png    # Screenshot specific element
```

### Query Elements

```bash
rodney exists ".loading"           # Exit 0 if exists, exit 1 if not
rodney count "li.item"             # Number of matching elements
rodney visible "#modal"            # Exit 0 if visible, exit 1 if not
rodney assert 'document.title' 'Home'              # Equality check
rodney assert 'document.querySelector("h1") !== null'  # Truthy check
```

### Tab Management

```bash
rodney pages                       # List tabs (* marks active)
rodney newpage https://...         # Open URL in new tab
rodney page 1                      # Switch to tab by index
rodney closepage 1                 # Close tab by index
```

## Element Discovery with Accessibility Tree

When you don't know the page structure, use the accessibility tree to find elements:

```bash
# Full accessibility tree
rodney ax-tree
rodney ax-tree --depth 3           # Limit depth
rodney ax-tree --json              # JSON output

# Find elements by role or name
rodney ax-find --role button
rodney ax-find --name "Submit"
rodney ax-find --role link --name "Home"
rodney ax-find --role button --json

# Inspect a specific element's accessibility properties
rodney ax-node "#submit-btn"
rodney ax-node "h1" --json
```

Workflow for unknown pages:
1. `rodney ax-tree --depth 3` to get page overview
2. `rodney ax-find --role <role>` to locate interactive elements
3. Use the selectors from the tree to interact

## Shell Scripting Patterns

### Capture and use values

```bash
title=$(rodney title)
url=$(rodney url)
count=$(rodney count "li.item")
```

### Conditional logic

```bash
if rodney exists ".error-message"; then
    rodney text ".error-message"
fi
```

### Multi-step workflow

```bash
rodney start
rodney open https://example.com/login
rodney waitstable
rodney input "#email" "user@example.com"
rodney input "#password" "secret"
rodney click "button[type=submit]"
rodney waitstable
rodney screenshot result.png
rodney stop
```

### Assertions for verification

```bash
rodney assert 'document.title' 'Dashboard'
rodney assert 'document.querySelectorAll(".item").length' '3'
rodney visible "#main-content"
```

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Check failed (condition not met, but command ran fine) |
| `2` | Error (bad args, no browser session, timeout) |

## Configuration

| Variable | Default | Description |
|---|---|---|
| `RODNEY_HOME` | `~/.rodney` | State/profile directory |
| `ROD_CHROME_BIN` | `/usr/bin/google-chrome` | Chrome binary path |
| `ROD_TIMEOUT` | `30` | Default timeout in seconds |

## Quick Reference

| Category | Commands |
|---|---|
| **Lifecycle** | `start`, `stop`, `status`, `connect` |
| **Navigate** | `open`, `back`, `forward`, `reload`, `clear-cache` |
| **Extract** | `url`, `title`, `text`, `html`, `attr`, `pdf`, `js` |
| **Interact** | `click`, `input`, `clear`, `select`, `submit`, `hover`, `focus`, `file` |
| **Wait** | `wait`, `waitload`, `waitstable`, `waitidle`, `sleep` |
| **Screenshot** | `screenshot`, `screenshot-el` |
| **Tabs** | `pages`, `page`, `newpage`, `closepage` |
| **Query** | `exists`, `count`, `visible`, `assert` |
| **Accessibility** | `ax-tree`, `ax-find`, `ax-node` |
| **Download** | `download` |
