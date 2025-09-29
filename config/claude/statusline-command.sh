#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)
echo "$input" > /tmp/claude-statusline-input.json

# Extract data from JSON
workspace_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
total_cost=$(echo "$input" | jq -r '(.cost.total_cost_usd // 0) | . * 100 | round / 100')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Build output parts
output=""

# Project directory (basename only)
if [ -n "$project_dir" ] && [ "$project_dir" != "null" ]; then
    project_name=$(basename "$project_dir")
    output="${output}\033[1;34m${project_name}\033[0m"
fi

# Change to workspace directory for git operations
cd "$workspace_dir" 2>/dev/null || cd "$HOME"

# Get git branch
branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null)

if [ -n "$branch" ]; then
    # Check git status
    has_staged=$(git --no-optional-locks diff --cached --quiet 2>/dev/null; echo $?)
    has_unstaged=$(git --no-optional-locks diff --quiet 2>/dev/null; echo $?)
    has_untracked=$(git --no-optional-locks ls-files --others --exclude-standard | head -n1)

    # Build status indicators
    indicators=""
    if [ "$has_staged" -eq 1 ]; then
        indicators="${indicators}● "  # Staged changes
    fi
    if [ "$has_unstaged" -eq 1 ]; then
        indicators="${indicators}✗ "  # Unstaged changes
    fi
    if [ -n "$has_untracked" ]; then
        indicators="${indicators}? "  # Untracked files
    fi

    # Check for upstream differences
    upstream=$(git --no-optional-locks rev-parse --abbrev-ref @{upstream} 2>/dev/null)
    if [ -n "$upstream" ]; then
        ahead=$(git --no-optional-locks rev-list --count @{upstream}..HEAD 2>/dev/null)
        behind=$(git --no-optional-locks rev-list --count HEAD..@{upstream} 2>/dev/null)

        if [ "$ahead" -gt 0 ]; then
            indicators="${indicators}↑$ahead "
        fi
        if [ "$behind" -gt 0 ]; then
            indicators="${indicators}↓$behind "
        fi
    fi

    # If no indicators, repository is clean
    if [ -z "$indicators" ]; then
        indicators="✓ "
    fi

    # Add delimiter if project_dir was shown
    if [ -n "$output" ]; then
        output="${output} \033[0;90m|\033[0m "
    fi
    output="${output}\033[0;36m${branch}\033[0m \033[0;33m${indicators}\033[0m"
fi

# Cost information
if [ "$total_cost" != "0" ] && [ "$total_cost" != "null" ]; then
    # Add delimiter if previous content exists
    if [ -n "$output" ]; then
        output="${output}\033[0;90m|\033[0m "
    fi
    output="${output}\033[0;35m\$${total_cost}\033[0m"
fi

# Lines added/removed
if [ "$lines_added" != "0" ] || [ "$lines_removed" != "0" ]; then
    # Add delimiter if previous content exists
    if [ -n "$output" ]; then
        output="${output} \033[0;90m|\033[0m "
    fi
    if [ "$lines_added" != "0" ]; then
        output="${output}\033[0;32m+${lines_added}\033[0m"
    fi
    if [ "$lines_removed" != "0" ]; then
        if [ "$lines_added" != "0" ]; then
            output="${output} "
        fi
        output="${output}\033[0;31m-${lines_removed}\033[0m"
    fi
fi

echo -en "$output"
