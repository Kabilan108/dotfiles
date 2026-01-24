# Sweep AI Autocomplete Plugin - Deep Technical Analysis

## Executive Summary

This document provides a comprehensive analysis of the Sweep AI Autocomplete plugin for JetBrains IDEs. Due to network restrictions preventing direct download and decompilation, this analysis is based on extensive research of Sweep's official blog posts, documentation, Hugging Face model cards, and community discussions.

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

Sweep AI uses a **custom inference engine** rather than calling external APIs like OpenAI/Anthropic:

```
┌─────────────────────────────────────────────────────────────────┐
│                      JetBrains IDE                               │
│  ┌─────────────────┐   ┌─────────────────┐   ┌──────────────┐  │
│  │  PSI (Program   │   │  Context        │   │  Inline      │  │
│  │  Structure      │──▶│  Builder        │──▶│  Completion  │  │
│  │  Interface)     │   │                 │   │  Provider    │  │
│  └─────────────────┘   └────────┬────────┘   └──────────────┘  │
└──────────────────────────────────┼──────────────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │    Sweep Inference Engine    │
                    │  (Custom datacenter GPUs)    │
                    │  - Speculative Decoding      │
                    │  - KV Cache Optimization     │
                    │  - Regional Proximity        │
                    └─────────────────────────────┘
```

### 1.2 Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Custom inference engine** | Control over latency, speculative decoding, GPU provisioning |
| **JetBrains-exclusive** | Leverage PSI for instant definition lookup |
| **Regional datacenters** | Reduce network latency (143ms → 32ms for west coast) |
| **1.5B parameter model** | Fast local inference, beats 7B models on benchmarks |

### 1.3 Latency Budget

Sweep operates within a **100ms total latency budget**:

| Component | Time |
|-----------|------|
| PSI lookup (cold cache) | ~30ms |
| PSI lookup (warm cache) | <1ms |
| Network latency (regional) | ~30ms |
| TTFT (warm KV cache) | ~10ms |
| Decoding | ~50ms |
| UI rendering | ~10ms |

---

## 2. Context Building (CRITICAL)

### 2.1 The PSI Advantage

Sweep leverages JetBrains' **Program Structure Interface (PSI)** - an in-process semantic code model:

```
Traditional Approach (VSCode + LSP):
┌─────────┐    IPC/Network    ┌─────────────┐
│  Editor │ ◀───────────────▶ │  LSP Server │
└─────────┘                   └─────────────┘

JetBrains PSI Approach:
┌───────────────────────────────────────────┐
│                 IDE Process               │
│  ┌─────────┐    In-Memory    ┌─────────┐  │
│  │  Editor │ ◀─────────────▶ │   PSI   │  │
│  └─────────┘                 └─────────┘  │
└───────────────────────────────────────────┘
```

**Why PSI matters:**
- Instant type resolution without network calls
- Maintains perfect representation of codebase in memory
- Updated incrementally as you type
- Works on any codebase/language the IDE has indexed

### 2.2 Definition Lookup Strategy

When the cursor is at `client.query(`:

```python
# PROBLEM: Searching for "client" returns irrelevant results
results = search("client")  # Returns hundreds of occurrences

# SOLUTION: PSI resolves the actual type
client_type = psi.resolve_type("client")  # → DatabaseClient
definition = psi.get_definition(client_type)  # → Exact class definition
```

**The key insight:** PSI distinguishes between where code is *used* vs where it's *defined*.

### 2.3 Context Window Composition

Based on research, Sweep's context likely includes:

```
┌─────────────────────────────────────────────────────────────┐
│ CONTEXT WINDOW (~4K-8K tokens)                              │
├─────────────────────────────────────────────────────────────┤
│ 1. DEFINITIONS (from PSI)                                   │
│    - Type definitions around cursor                         │
│    - Method signatures being called                         │
│    - Import statements                                      │
├─────────────────────────────────────────────────────────────┤
│ 2. RECENT EDITS (for next-edit prediction)                  │
│    - Diffs from current editing session                     │
│    - Recently modified functions                            │
│    - Commit context (what else changed)                     │
├─────────────────────────────────────────────────────────────┤
│ 3. CURRENT FILE CONTEXT                                     │
│    - Code before cursor (prefix)                            │
│    - Code after cursor (suffix)                             │
│    - Surrounding function/class context                     │
├─────────────────────────────────────────────────────────────┤
│ 4. RELATED FILES                                            │
│    - Other files touched in same commit                     │
│    - Files with related definitions                         │
└─────────────────────────────────────────────────────────────┘
```

### 2.4 Why NOT to Use Search-Based Context

Sweep explicitly states problems with traditional approaches:

| Approach | Problem |
|----------|---------|
| **Vector search** | Too slow for real-time (>100ms), no semantic understanding |
| **TF-IDF** | Returns dozens of irrelevant files, can't distinguish usage vs definition |
| **Embedding search** | Requires indexing, latency spikes, buries actual definitions |

---

## 3. Prompt Format

### 3.1 Traditional FIM Format (Starting Point)

Sweep started with standard Fill-in-the-Middle:

```
<|prefix|>def get_car_metadata(car: Car) -> str:
    return f"{<|suffix|>} {car.model} {car.year}"<|middle|>
```

**Output:** `car.make`

### 3.2 Next-Edit Prompt Format

For next-edit autocomplete, the format evolved to include recent diffs:

```
[FILE CONTEXT]
# Recent definitions resolved via PSI
class DatabaseClient:
    def query(self, sql: str) -> QueryResult:
        ...

[RECENT DIFFS]
# Changes from current editing session
--- a/utils.py
+++ b/utils.py
@@ -10,6 +10,7 @@
 def process_data(data):
+    max_depth = 10  # Added this parameter

[CURRENT STATE]
# Code around cursor with cursor position marked
def search_recursive(node, value):
    if node is None:
        return None
    self.search_recursive(node.left, value,█)

[PREDICTED EDIT]
# Model outputs rewritten code
```

### 3.3 Diff Format Discovery

Sweep tested **30+ diff formats** using genetic algorithms:

| Format | Performance |
|--------|-------------|
| Unified diff (`---/+++`) | Lower |
| **Simple original/updated blocks** | **Winner** |
| JSON patch | Lower |
| Line-by-line | Lower |

**Winning format:**
```
<original>
self.search_recursive(node.left, value,)
</original>
<updated>
self.search_recursive(node.left, value, max_depth - 1 if max_depth is not None else None)
</updated>
```

---

## 4. Model Architecture

### 4.1 Model Specifications

| Attribute | Value |
|-----------|-------|
| **Model name** | sweep-next-edit-1.5B |
| **Parameters** | 1.5 billion |
| **Format** | GGUF Q8_0 |
| **Size** | 1.54 GB |
| **License** | Apache 2.0 (open weights) |
| **Base model** | Likely Qwen2.5-Coder |

### 4.2 Training Approach

```
Training Pipeline:
┌───────────────────────────────────────────────────────────┐
│ 1. DATA COLLECTION                                        │
│    - ~80K FIM examples from 400 OSS repos                │
│    - Repos created in past 6 months (avoid contamination)│
│    - Permissively licensed                               │
└───────────────────────┬───────────────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────────────┐
│ 2. AST-DIFF SAMPLING                                      │
│    - Diff AST trees before/after commit                  │
│    - Only sample from CHANGED AST nodes                  │
│    - Upsamples frequently edited code patterns           │
└───────────────────────┬───────────────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────────────┐
│ 3. SYNTAX-AWARE FIM (SAFIM)                               │
│    - All completions are valid AST nodes                 │
│    - No random substrings breaking syntax                │
└───────────────────────┬───────────────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────────────┐
│ 4. SUPERVISED FINE-TUNING                                 │
│    - Full-parameter SFT via TRL                          │
│    - 8x H200 GPUs on Modal                               │
│    - 4 hours training time                               │
└───────────────────────┬───────────────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────────────┐
│ 5. REINFORCEMENT LEARNING                                 │
│    - Tree-sitter parse validation as reward              │
│    - Ensures syntactically valid outputs                 │
└───────────────────────────────────────────────────────────┘
```

### 4.3 Why AST-Diff Sampling Matters

Standard FIM treats code as text, leading to:
- Completions that break at AST boundaries
- Random sampling of rarely-edited patterns

**AST-diff sampling ensures:**
- Focus on code patterns developers actually modify
- Completions respect syntactic structure
- Higher acceptance rate in practice

---

## 5. Inference Optimizations

### 5.1 Speculative Decoding

For next-edit autocomplete, **>90% of tokens are unchanged** when rewriting around cursor:

```
Input:  self.search_recursive(node.left, value,)
Output: self.search_recursive(node.left, value, max_depth - 1)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^            ^^^
        (identical - can be speculated)         (new tokens)
```

**Performance gains:**
- 10x improvement on decoding time
- 5x improvement on total time

### 5.2 KV Cache Optimization

```
Cold Request:
┌─────────┐    ┌─────────────┐    ┌─────────────┐
│ Request │───▶│ Build Cache │───▶│ Generate    │  ~30ms + generation
└─────────┘    └─────────────┘    └─────────────┘

Warm Request (same file context):
┌─────────┐    ┌─────────────┐
│ Request │───▶│ Generate    │  <1ms + generation
└─────────┘    │ (reuse KV)  │
               └─────────────┘
```

### 5.3 Early Termination

Sweep implements a trick for faster perceived latency:

```python
# Pseudocode for early termination
def generate_completion(prompt):
    tokens = []
    for token in stream_tokens(prompt):
        tokens.append(token)
        if has_enough_changes(tokens):
            # Return early, cancel rest of stream
            return format_suggestion(tokens)
    return format_suggestion(tokens)
```

---

## 6. Completion Triggers & Display

### 6.1 Trigger Strategy

Based on research, Sweep likely triggers completions:

| Trigger | Description |
|---------|-------------|
| **On keystroke** | Response times faster than typing speed enable per-keystroke suggestions |
| **On pause** | Traditional debounce for expensive operations |
| **After specific tokens** | `.`, `(`, `,`, etc. |
| **After edits** | When code structure changes (next-edit prediction) |

### 6.2 Debouncing

> "There is currently no ready-made solution for debounce/throttle in the IntelliJ platform, so plugin developers have to take care of caching/throttling/timeouts in their completion contributor by themselves."

Sweep handles this internally with their <100ms latency enabling near-instant responses.

### 6.3 Display Strategy

**Single-line first:**
> "To simplify the process of reviewing suggestions, multiline code suggestions are now displayed only after accepting a single-line suggestion, allowing you to review and accept code gradually."

**Next-edit jumping:**
- Tab key accepts suggestion AND jumps to next predicted edit location
- Enables "flow state" for repetitive changes

### 6.4 Diff Visualization

For next-edit suggestions that modify existing code:

```
# Visual diff in editor
- self.search_recursive(node.left, value,)
+ self.search_recursive(node.left, value, max_depth - 1)
```

---

## 7. Caching Strategy

### 7.1 PSI Cache

| State | Lookup Time |
|-------|-------------|
| Cold (first access) | ~30ms |
| Warm (subsequent) | <1ms |

### 7.2 Model Cache

- **KV cache** for repeated contexts
- **Regional caching** in datacenters
- **Client-side caching** of recent suggestions

---

## 8. Key Differentiators from Competitors

### 8.1 vs GitHub Copilot

| Feature | Sweep | Copilot |
|---------|-------|---------|
| Model | Custom 1.5B | GPT-4o-mini via API |
| Latency control | Full | Limited |
| Context | PSI (rich semantic) | Limited to visible context |
| Next-edit prediction | Yes | Limited |
| Local inference | Yes (optional) | No |
| Cost | Free | $10-19/month |

### 8.2 vs Cursor

| Feature | Sweep | Cursor |
|---------|-------|--------|
| IDE | JetBrains only | VSCode fork |
| Context | PSI (instant) | LSP (IPC overhead) |
| Edit speed | <1 second for 500-line files | Slower, more agentic |
| Tab jumping | Yes | Yes |

---

## 9. Implementation Guide for Neovim

### 9.1 Key Components to Build

```lua
-- Neovim equivalent architecture
local sweep_nvim = {
    -- 1. Context Builder (replaces PSI)
    context = {
        get_definitions = function()
            -- Use LSP for type resolution
            -- vim.lsp.buf.definition()
            -- vim.lsp.buf.type_definition()
        end,
        get_recent_edits = function()
            -- Track buffer changes
            -- Use vim.api.nvim_buf_attach() for change events
        end,
        get_cursor_context = function()
            -- Prefix/suffix around cursor
        end,
    },

    -- 2. Model Interface
    model = {
        -- Local: llama.cpp, ollama, LM Studio
        -- Remote: Custom API
    },

    -- 3. Completion Provider
    completion = {
        trigger = function() end,
        display = function() end,
        accept = function() end,
    },
}
```

### 9.2 Context Building for Neovim

```lua
-- Replicate PSI behavior with LSP
local function get_definitions_at_cursor()
    local params = vim.lsp.util.make_position_params()

    -- Get type definition
    local type_def = vim.lsp.buf_request_sync(
        0, 'textDocument/typeDefinition', params, 1000
    )

    -- Get hover info for signatures
    local hover = vim.lsp.buf_request_sync(
        0, 'textDocument/hover', params, 1000
    )

    -- Get document symbols for context
    local symbols = vim.lsp.buf_request_sync(
        0, 'textDocument/documentSymbol', {
            textDocument = vim.lsp.util.make_text_document_params()
        }, 1000
    )

    return {
        type_definition = type_def,
        hover = hover,
        symbols = symbols,
    }
end
```

### 9.3 Tracking Recent Edits

```lua
-- Track edits for next-edit prediction
local edit_history = {}

vim.api.nvim_buf_attach(0, false, {
    on_lines = function(_, buf, _, first, last_old, last_new, _)
        table.insert(edit_history, {
            buffer = buf,
            range = {first, last_old, last_new},
            timestamp = vim.loop.now(),
            file = vim.api.nvim_buf_get_name(buf),
        })
        -- Keep only recent edits
        while #edit_history > 20 do
            table.remove(edit_history, 1)
        end
    end,
})
```

### 9.4 Prompt Template

```lua
local function build_prompt(cursor_pos)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local row, col = cursor_pos[1], cursor_pos[2]

    -- Split into prefix and suffix
    local prefix_lines = vim.list_slice(lines, 1, row)
    prefix_lines[#prefix_lines] = string.sub(prefix_lines[#prefix_lines], 1, col)

    local suffix_lines = vim.list_slice(lines, row, #lines)
    suffix_lines[1] = string.sub(suffix_lines[1], col + 1)

    local prefix = table.concat(prefix_lines, "\n")
    local suffix = table.concat(suffix_lines, "\n")

    -- Get definitions via LSP
    local definitions = get_definitions_at_cursor()

    -- Get recent edits
    local recent_diffs = format_recent_edits(edit_history)

    return string.format([[
[DEFINITIONS]
%s

[RECENT EDITS]
%s

[CURRENT FILE]
<|prefix|>%s<|suffix|>%s<|middle|>
]], definitions, recent_diffs, prefix, suffix)
end
```

### 9.5 Model Options

| Option | Latency | Quality | Setup |
|--------|---------|---------|-------|
| **sweep-next-edit-1.5B via Ollama** | ~200ms | Good | Easy |
| **sweep-next-edit-1.5B via llama.cpp** | ~100ms | Good | Medium |
| **Qwen2.5-Coder-1.5B** | ~150ms | Good | Easy |
| **DeepSeek-Coder-1.3B** | ~150ms | Good | Easy |
| **Remote API (Claude/GPT)** | ~500ms+ | Best | Easy |

---

## 10. Sources & References

1. [Sweep AI Blog - Autocomplete Context](https://blog.sweep.dev/posts/autocomplete-context)
2. [Sweep AI Blog - Next-Edit JetBrains](https://blog.sweep.dev/posts/next-edit-jetbrains)
3. [Sweep Documentation](https://docs.sweep.dev/)
4. [Sweep Next-Edit 1.5B Model (Hugging Face)](https://huggingface.co/sweepai/sweep-next-edit-1.5B)
5. [JetBrains PSI Documentation](https://plugins.jetbrains.com/docs/intellij/psi.html)
6. [Hacker News Discussion - Open-weights Model](https://news.ycombinator.com/item?id=46713106)
7. [Hacker News Discussion - JetBrains Plugin](https://news.ycombinator.com/item?id=45505487)
8. [JetBrains AI Completion Blog](https://blog.jetbrains.com/ai/2024/10/complete-the-un-completable-the-state-of-ai-completion-in-jetbrains-ides/)
9. [Sweep GitHub Organization](https://github.com/sweepai)
10. [ByteIota Analysis](https://byteiota.com/sweep-ai-1-5b-model-beats-github-copilot-at-code-autocomplete/)

---

## 11. Appendix: Neovim Plugins for Reference

### Existing Next-Edit Implementations

1. **[nes.nvim](https://github.com/Xuyuanp/nes.nvim)** - Next edit suggestion using Copilot
2. **[cursortab.nvim](https://github.com/reachingforthejack/cursortab.nvim)** - Reverse-engineered Cursor Tab API
3. **[sidekick.nvim](https://github.com/folke/sidekick.nvim)** - Copilot LSP "Next Edit Suggestions" integration
4. **[avante.nvim](https://github.com/yetone/avante.nvim)** - Cursor-like AI assistant

### Key Takeaways for Neovim Implementation

1. **LSP is your PSI** - Use LSP for definition lookup, but be aware of IPC latency
2. **Track edits** - Maintain edit history for next-edit prediction context
3. **Use local models** - sweep-next-edit-1.5B is designed for local inference
4. **Simple diff format** - Original/updated blocks outperform unified diffs
5. **Speculative decoding** - Enable in llama.cpp/ollama for 5-10x speedup
6. **Debounce wisely** - ~100ms debounce, or per-keystroke if inference is fast enough
