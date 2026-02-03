#!/usr/bin/env -S uv --quiet run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""
Claude Code Session Export Tool

Exports Claude Code sessions to structured output directories.
"""

import argparse
import getpass
import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import TypedDict
from xml.dom import minidom

CCTRACE_VERSION = "3.0.0"


def clean_text_for_xml(text: str) -> str:
    if not text:
        return text
    return re.sub(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]", "", str(text))


def get_normalized_project_dir(project_path: str) -> str:
    project_path = str(project_path)
    if os.name == "nt":
        project_dir_name = (
            project_path.replace("\\", "-")
            .replace(":", "-")
            .replace("/", "-")
            .replace(".", "-")
            .replace("_", "-")
        )
    else:
        normalized = project_path.replace("\\", "/")
        project_dir_name = (
            normalized.replace("/", "-").replace(".", "-").replace("_", "-")
        )

    if project_dir_name.startswith("-"):
        project_dir_name = project_dir_name[1:]

    if os.name == "nt":
        return project_dir_name
    return f"-{project_dir_name}"


def find_project_sessions(project_path: str) -> list[dict]:
    normalized_dir = get_normalized_project_dir(project_path)
    claude_project_dir = Path.home() / ".claude" / "projects" / normalized_dir

    if not claude_project_dir.exists():
        return []

    jsonl_files = []
    for file in claude_project_dir.glob("*.jsonl"):
        if file.name.startswith("agent-"):
            continue
        stat = file.stat()
        jsonl_files.append(
            {"path": file, "mtime": stat.st_mtime, "session_id": file.stem}
        )

    return sorted(jsonl_files, key=lambda x: x["mtime"], reverse=True)


class SessionMetadata(TypedDict):
    session_id: str | None
    start_time: str | None
    end_time: str | None
    project_dir: str | None
    total_messages: int
    user_messages: int
    assistant_messages: int
    tool_uses: int
    models_used: set[str]


def parse_jsonl_file(file_path: Path) -> tuple[list[dict], SessionMetadata]:
    messages = []
    metadata: SessionMetadata = {
        "session_id": None,
        "start_time": None,
        "end_time": None,
        "project_dir": None,
        "total_messages": 0,
        "user_messages": 0,
        "assistant_messages": 0,
        "tool_uses": 0,
        "models_used": set(),
    }

    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            try:
                data = json.loads(line.strip())
                messages.append(data)

                if metadata["session_id"] is None and "sessionId" in data:
                    metadata["session_id"] = data["sessionId"]

                if "cwd" in data and metadata["project_dir"] is None:
                    metadata["project_dir"] = data["cwd"]

                if "timestamp" in data:
                    ts = data["timestamp"]
                    if metadata["start_time"] is None or ts < metadata["start_time"]:
                        metadata["start_time"] = ts
                    if metadata["end_time"] is None or ts > metadata["end_time"]:
                        metadata["end_time"] = ts

                if "message" in data and "role" in data["message"]:
                    role = data["message"]["role"]
                    if role == "user":
                        metadata["user_messages"] += 1
                    elif role == "assistant":
                        metadata["assistant_messages"] += 1
                        if "model" in data["message"]:
                            metadata["models_used"].add(data["message"]["model"])

                if "message" in data and "content" in data["message"]:
                    for content in data["message"]["content"]:
                        if (
                            isinstance(content, dict)
                            and content.get("type") == "tool_use"
                        ):
                            metadata["tool_uses"] += 1

            except json.JSONDecodeError:
                continue

    metadata["total_messages"] = len(messages)
    return messages, metadata


def format_message_markdown(message_data: dict) -> str:
    output = []

    if "message" not in message_data:
        return ""

    msg = message_data["message"]
    timestamp = message_data.get("timestamp", "")

    if timestamp:
        dt = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        output.append(f"**[{dt.strftime('%Y-%m-%d %H:%M:%S')}]**")

    role = msg.get("role", "unknown")
    if role == "user":
        output.append("\n### User\n")
    elif role == "assistant":
        model = msg.get("model", "")
        output.append(f"\n### Assistant ({model})\n")

    if "content" in msg:
        if isinstance(msg["content"], str):
            output.append(msg["content"])
        elif isinstance(msg["content"], list):
            for content in msg["content"]:
                if isinstance(content, dict):
                    content_type = content.get("type")

                    if content_type == "text":
                        output.append(content.get("text", ""))

                    elif content_type == "thinking":
                        output.append("\n<details>")
                        output.append(
                            "<summary>Internal Reasoning (click to expand)</summary>\n"
                        )
                        output.append("```")
                        output.append(content.get("thinking", ""))
                        output.append("```")
                        output.append("</details>\n")

                    elif content_type == "tool_use":
                        tool_name = content.get("name", "unknown")
                        tool_id = content.get("id", "")
                        output.append(f"\n**Tool Use: {tool_name}** (ID: {tool_id})")
                        output.append("```json")
                        output.append(json.dumps(content.get("input", {}), indent=2))
                        output.append("```\n")

                    elif content_type == "tool_result":
                        output.append("\n**Tool Result:**")
                        output.append("```")
                        result = content.get("content", "")
                        if isinstance(result, str):
                            output.append(result[:5000])
                            if len(result) > 5000:
                                output.append(
                                    f"\n... (truncated, {len(result) - 5000} chars omitted)"
                                )
                        else:
                            output.append(str(result))
                        output.append("```\n")

    return "\n".join(output)


def format_message_xml(message_data: dict, parent_element: ET.Element) -> None:
    msg_elem = ET.SubElement(parent_element, "message")

    msg_elem.set("uuid", message_data.get("uuid", ""))
    if message_data.get("parentUuid"):
        msg_elem.set("parent-uuid", message_data["parentUuid"])
    msg_elem.set("timestamp", message_data.get("timestamp", ""))

    if "type" in message_data:
        ET.SubElement(msg_elem, "event-type").text = message_data["type"]
    if "cwd" in message_data:
        ET.SubElement(msg_elem, "working-directory").text = message_data["cwd"]
    if "requestId" in message_data:
        ET.SubElement(msg_elem, "request-id").text = message_data["requestId"]

    if "message" in message_data:
        msg = message_data["message"]

        if "role" in msg:
            ET.SubElement(msg_elem, "role").text = msg["role"]
        if "model" in msg:
            ET.SubElement(msg_elem, "model").text = msg["model"]

        if "content" in msg:
            content_elem = ET.SubElement(msg_elem, "content")

            if isinstance(msg["content"], str):
                content_elem.text = msg["content"]
            elif isinstance(msg["content"], list):
                for content in msg["content"]:
                    if isinstance(content, dict):
                        content_type = content.get("type")

                        if content_type == "text":
                            text_elem = ET.SubElement(content_elem, "text")
                            text_elem.text = clean_text_for_xml(content.get("text", ""))

                        elif content_type == "thinking":
                            thinking_elem = ET.SubElement(content_elem, "thinking")
                            if "signature" in content:
                                thinking_elem.set("signature", content["signature"])
                            thinking_elem.text = clean_text_for_xml(
                                content.get("thinking", "")
                            )

                        elif content_type == "tool_use":
                            tool_elem = ET.SubElement(content_elem, "tool-use")
                            tool_elem.set("id", content.get("id", ""))
                            tool_elem.set("name", content.get("name", ""))
                            input_elem = ET.SubElement(tool_elem, "input")
                            input_elem.text = clean_text_for_xml(
                                json.dumps(content.get("input", {}), indent=2)
                            )

                        elif content_type == "tool_result":
                            result_elem = ET.SubElement(content_elem, "tool-result")
                            if "tool_use_id" in content:
                                result_elem.set("tool-use-id", content["tool_use_id"])
                            result_content = content.get("content", "")
                            if isinstance(result_content, str):
                                result_elem.text = clean_text_for_xml(result_content)
                            else:
                                result_elem.text = clean_text_for_xml(
                                    str(result_content)
                                )

        if "usage" in msg:
            usage_elem = ET.SubElement(msg_elem, "usage")
            usage = msg["usage"]
            if "input_tokens" in usage:
                ET.SubElement(usage_elem, "input-tokens").text = str(
                    usage["input_tokens"]
                )
            if "output_tokens" in usage:
                ET.SubElement(usage_elem, "output-tokens").text = str(
                    usage["output_tokens"]
                )
            if "cache_creation_input_tokens" in usage:
                ET.SubElement(usage_elem, "cache-creation-tokens").text = str(
                    usage["cache_creation_input_tokens"]
                )
            if "cache_read_input_tokens" in usage:
                ET.SubElement(usage_elem, "cache-read-tokens").text = str(
                    usage["cache_read_input_tokens"]
                )
            if "service_tier" in usage:
                ET.SubElement(usage_elem, "service-tier").text = usage["service_tier"]

    if "toolUseResult" in message_data:
        tool_result = message_data["toolUseResult"]
        if isinstance(tool_result, dict):
            tool_meta = ET.SubElement(msg_elem, "tool-execution-metadata")
            if "bytes" in tool_result:
                ET.SubElement(tool_meta, "response-bytes").text = str(
                    tool_result["bytes"]
                )
            if "code" in tool_result:
                ET.SubElement(tool_meta, "response-code").text = str(
                    tool_result["code"]
                )
            if "codeText" in tool_result:
                ET.SubElement(tool_meta, "response-text").text = tool_result["codeText"]
            if "durationMs" in tool_result:
                ET.SubElement(tool_meta, "duration-ms").text = str(
                    tool_result["durationMs"]
                )
            if "url" in tool_result:
                ET.SubElement(tool_meta, "url").text = tool_result["url"]


def prettify_xml(elem: ET.Element) -> str:
    try:
        rough_string = ET.tostring(elem, encoding="unicode", method="xml")
        reparsed = minidom.parseString(rough_string)
        return reparsed.toprettyxml(indent="  ")
    except Exception:
        return ET.tostring(elem, encoding="unicode", method="xml")


# ---------------------------------------------------------------------------
# Session data collection
# ---------------------------------------------------------------------------


def collect_agent_sessions(
    project_path: str, session_id: str, messages: list[dict]
) -> dict[str, Path]:
    agents: dict[str, Path] = {}

    agent_ids = set()
    for msg in messages:
        if "agentId" in msg:
            agent_id = msg["agentId"]
            if agent_id and len(agent_id) == 7:
                agent_ids.add(agent_id)

    normalized_dir = get_normalized_project_dir(project_path)
    claude_project_dir = Path.home() / ".claude" / "projects" / normalized_dir

    if not claude_project_dir.exists():
        return agents

    # Pattern 1: agent-*.jsonl at project root (older format)
    for agent_file in claude_project_dir.glob("agent-*.jsonl"):
        agent_id = agent_file.stem.removeprefix("agent-")
        if agent_id in agent_ids:
            try:
                with open(agent_file, "r", encoding="utf-8") as f:
                    first_line = f.readline()
                    if first_line:
                        data = json.loads(first_line)
                        if data.get("sessionId") == session_id:
                            agents[agent_id] = agent_file
            except Exception:
                pass

    # Pattern 2: <session-id>/subagents/agent-*.jsonl
    subagent_dir = claude_project_dir / session_id / "subagents"
    if subagent_dir.exists():
        for agent_file in subagent_dir.glob("agent-*.jsonl"):
            agent_id = agent_file.stem.removeprefix("agent-")
            agents[agent_id] = agent_file

    return agents


def collect_file_history(session_id: str) -> list[Path]:
    file_history_dir = Path.home() / ".claude" / "file-history" / session_id
    if not file_history_dir.exists():
        return []
    return [f for f in file_history_dir.iterdir() if f.is_file()]


def collect_plan_file(slug: str | None) -> Path | None:
    if not slug:
        return None
    plan_file = Path.home() / ".claude" / "plans" / f"{slug}.md"
    return plan_file if plan_file.exists() else None


def collect_todos(session_id: str) -> list[Path]:
    todos_dir = Path.home() / ".claude" / "todos"
    if not todos_dir.exists():
        return []
    return list(todos_dir.glob(f"{session_id}-*.json"))


def collect_session_env(session_id: str) -> Path | None:
    session_env_dir = Path.home() / ".claude" / "session-env" / session_id
    if session_env_dir.exists() and any(session_env_dir.iterdir()):
        return session_env_dir
    return None


class ProjectConfig(TypedDict):
    commands: list[Path]
    skills: list[Path]
    hooks: list[Path]
    agents: list[Path]
    rules: list[Path]
    settings: Path | None
    claude_md: Path | None


def collect_project_config(project_path: str) -> ProjectConfig:
    project_path_obj = Path(project_path)
    config: ProjectConfig = {
        "commands": [],
        "skills": [],
        "hooks": [],
        "agents": [],
        "rules": [],
        "settings": None,
        "claude_md": None,
    }

    claude_dir = project_path_obj / ".claude"

    for commands_dir in [claude_dir / "commands", project_path_obj / "commands"]:
        if commands_dir.exists():
            config["commands"].extend(commands_dir.glob("*.md"))

    for key, subdir, pattern in [
        ("skills", "skills", "*.md"),
        ("agents", "agents", "*.md"),
        ("rules", "rules", "*.md"),
    ]:
        d = claude_dir / subdir
        if d.exists():
            config[key].extend(d.glob(pattern))

    hooks_dir = claude_dir / "hooks"
    if hooks_dir.exists():
        config["hooks"] = [f for f in hooks_dir.iterdir() if f.is_file()]

    settings_file = claude_dir / "settings.json"
    if settings_file.exists():
        config["settings"] = settings_file

    claude_md = project_path_obj / "CLAUDE.md"
    if claude_md.exists():
        config["claude_md"] = claude_md

    return config


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------


class ManifestOriginalContext(TypedDict):
    user: str | None
    platform: str
    repo_path: str
    git_branch: str | None


class ManifestSessionData(TypedDict):
    main_session: str
    agent_sessions: list[str]
    file_history: list[str]
    plan_file: str | None
    todos: str | None
    session_env: str | None


class ManifestConfigSnapshot(TypedDict):
    commands: list[str]
    skills: list[str]
    hooks: list[str]
    agents: list[str]
    rules: list[str]
    settings: str | None
    claude_md: str | None


class ManifestStatistics(TypedDict):
    message_count: int
    user_messages: int
    assistant_messages: int
    tool_uses: int
    duration_seconds: int | None
    models_used: list[str]


class Manifest(TypedDict):
    cctrace_version: str
    export_timestamp: str
    session_id: str
    session_slug: str | None
    export_name: str
    claude_code_version: str | None
    original_context: ManifestOriginalContext
    session_data: ManifestSessionData
    config_snapshot: ManifestConfigSnapshot
    statistics: ManifestStatistics
    anonymized: bool


def generate_manifest(
    session_id: str,
    slug: str | None,
    export_name: str,
    metadata: SessionMetadata,
    messages: list[dict],
    session_files: dict,
    config_files: ProjectConfig,
    project_path: str,
    anonymized: bool = False,
) -> Manifest:
    claude_code_version = None
    for msg in messages:
        if "version" in msg:
            claude_code_version = msg["version"]
            break

    git_branch = None
    for msg in messages:
        if "gitBranch" in msg:
            git_branch = msg["gitBranch"]
            break

    manifest: Manifest = {
        "cctrace_version": CCTRACE_VERSION,
        "export_timestamp": datetime.now().isoformat() + "Z",
        "session_id": session_id,
        "session_slug": slug,
        "export_name": export_name,
        "claude_code_version": claude_code_version,
        "original_context": {
            "user": getpass.getuser() if not anonymized else None,
            "platform": sys.platform,
            "repo_path": str(project_path),
            "git_branch": git_branch,
        },
        "session_data": {
            "main_session": "session/main.jsonl",
            "agent_sessions": [
                f"session/agents/{Path(f).name}"
                for f in session_files.get("agents", {}).values()
            ],
            "file_history": [
                f"session/file-history/{Path(f).name}"
                for f in session_files.get("file_history", [])
            ],
            "plan_file": "session/plan.md" if session_files.get("plan") else None,
            "todos": "session/todos.json" if session_files.get("todos") else None,
            "session_env": "session/session-env/"
            if session_files.get("session_env")
            else None,
        },
        "config_snapshot": {
            "commands": [
                f"config/commands/{Path(f).name}"
                for f in config_files.get("commands", [])
            ],
            "skills": [
                f"config/skills/{Path(f).name}" for f in config_files.get("skills", [])
            ],
            "hooks": [
                f"config/hooks/{Path(f).name}" for f in config_files.get("hooks", [])
            ],
            "agents": [
                f"config/agents/{Path(f).name}" for f in config_files.get("agents", [])
            ],
            "rules": [
                f"config/rules/{Path(f).name}" for f in config_files.get("rules", [])
            ],
            "settings": "config/settings.json"
            if config_files.get("settings")
            else None,
            "claude_md": "config/CLAUDE.md" if config_files.get("claude_md") else None,
        },
        "statistics": {
            "message_count": metadata["total_messages"],
            "user_messages": metadata["user_messages"],
            "assistant_messages": metadata["assistant_messages"],
            "tool_uses": metadata["tool_uses"],
            "duration_seconds": None,
            "models_used": sorted(metadata["models_used"]),
        },
        "anonymized": anonymized,
    }

    st, et = metadata.get("start_time"), metadata.get("end_time")
    if st is not None and et is not None:
        try:
            start = datetime.fromisoformat(st.replace("Z", "+00:00"))
            end = datetime.fromisoformat(et.replace("Z", "+00:00"))
            manifest["statistics"]["duration_seconds"] = int(
                (end - start).total_seconds()
            )
        except Exception:
            pass

    return manifest


# ---------------------------------------------------------------------------
# Rendered markdown
# ---------------------------------------------------------------------------


def generate_rendered_markdown(
    messages: list[dict], metadata: SessionMetadata, manifest: Manifest
) -> str:
    lines = []

    lines.append(f"# Claude Code Session: {manifest['export_name']}")
    lines.append("")
    lines.append(f"> Exported from cctrace v{CCTRACE_VERSION}")
    lines.append("")

    lines.append("## Session Info")
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("|-------|-------|")
    lines.append(f"| Session ID | `{manifest['session_id']}` |")
    if manifest["session_slug"]:
        lines.append(f"| Session Name | {manifest['session_slug']} |")
    lines.append(f"| Project | `{manifest['original_context']['repo_path']}` |")
    if manifest["original_context"]["git_branch"]:
        lines.append(f"| Git Branch | `{manifest['original_context']['git_branch']}` |")
    lines.append(f"| Claude Code | v{manifest['claude_code_version']} |")
    lines.append(f"| Messages | {manifest['statistics']['message_count']} |")
    lines.append(f"| Tool Uses | {manifest['statistics']['tool_uses']} |")
    if manifest["statistics"]["duration_seconds"]:
        duration = manifest["statistics"]["duration_seconds"]
        if duration > 3600:
            duration_str = f"{duration // 3600}h {(duration % 3600) // 60}m"
        elif duration > 60:
            duration_str = f"{duration // 60}m {duration % 60}s"
        else:
            duration_str = f"{duration}s"
        lines.append(f"| Duration | {duration_str} |")
    lines.append(f"| Models | {', '.join(manifest['statistics']['models_used'])} |")
    lines.append("")

    lines.append("## Session Data")
    lines.append("")
    lines.append("| Component | Status |")
    lines.append("|-----------|--------|")
    lines.append("| Main Session | `session/main.jsonl` |")
    agent_count = len(manifest["session_data"]["agent_sessions"])
    lines.append(
        f"| Agent Sessions | {str(agent_count) + ' files' if agent_count else 'None'} |"
    )
    fh_count = len(manifest["session_data"]["file_history"])
    lines.append(
        f"| File History | {str(fh_count) + ' snapshots' if fh_count else 'None'} |"
    )
    lines.append(
        f"| Plan File | {'Included' if manifest['session_data']['plan_file'] else 'None'} |"
    )
    lines.append(
        f"| Todos | {'Included' if manifest['session_data']['todos'] else 'None'} |"
    )
    lines.append("")

    lines.append("## Project Config")
    lines.append("")
    lines.append("| Component | Status |")
    lines.append("|-----------|--------|")
    for label, key in [
        ("Commands", "commands"),
        ("Skills", "skills"),
        ("Hooks", "hooks"),
        ("Agents", "agents"),
        ("Rules", "rules"),
    ]:
        count = len(manifest["config_snapshot"][key])
        lines.append(f"| {label} | {str(count) + ' files' if count else 'None'} |")
    lines.append(
        f"| Settings | {'Included' if manifest['config_snapshot']['settings'] else 'None'} |"
    )
    lines.append(
        f"| CLAUDE.md | {'Included' if manifest['config_snapshot']['claude_md'] else 'None'} |"
    )
    lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Conversation")
    lines.append("")

    for msg in messages:
        formatted = format_message_markdown(msg)
        if formatted:
            lines.append(formatted)
            lines.append("")
            lines.append("---")
            lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Conversation file writers
# ---------------------------------------------------------------------------


def write_conversation_md(
    export_dir: Path,
    messages: list[dict],
    metadata: SessionMetadata,
) -> None:
    md_path = export_dir / "conversation.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# Claude Code Session Export\n\n")
        f.write(f"**Session ID:** `{metadata['session_id']}`\n")
        f.write(f"**Project:** `{metadata['project_dir']}`\n")
        f.write(f"**Start Time:** {metadata['start_time']}\n")
        f.write(f"**End Time:** {metadata['end_time']}\n")
        f.write(f"**Total Messages:** {metadata['total_messages']}\n")
        f.write(f"**User Messages:** {metadata['user_messages']}\n")
        f.write(f"**Assistant Messages:** {metadata['assistant_messages']}\n")
        f.write(f"**Tool Uses:** {metadata['tool_uses']}\n")
        f.write(f"**Models Used:** {', '.join(sorted(metadata['models_used']))}\n\n")
        f.write("---\n\n")

        for msg in messages:
            formatted = format_message_markdown(msg)
            if formatted:
                f.write(formatted)
                f.write("\n\n---\n\n")


def write_conversation_xml(
    export_dir: Path,
    messages: list[dict],
    metadata: SessionMetadata,
) -> None:
    root = ET.Element("claude-session")
    root.set("xmlns", "https://claude.ai/session-export/v1")
    root.set("export-version", "1.0")

    meta_elem = ET.SubElement(root, "metadata")
    ET.SubElement(meta_elem, "session-id").text = metadata["session_id"]
    ET.SubElement(meta_elem, "version").text = (
        messages[0].get("version", "") if messages else ""
    )
    ET.SubElement(meta_elem, "working-directory").text = metadata["project_dir"]
    ET.SubElement(meta_elem, "start-time").text = metadata["start_time"]
    ET.SubElement(meta_elem, "end-time").text = metadata["end_time"]
    ET.SubElement(meta_elem, "export-time").text = datetime.now().isoformat()

    stats_elem = ET.SubElement(meta_elem, "statistics")
    ET.SubElement(stats_elem, "total-messages").text = str(metadata["total_messages"])
    ET.SubElement(stats_elem, "user-messages").text = str(metadata["user_messages"])
    ET.SubElement(stats_elem, "assistant-messages").text = str(
        metadata["assistant_messages"]
    )
    ET.SubElement(stats_elem, "tool-uses").text = str(metadata["tool_uses"])

    models_elem = ET.SubElement(stats_elem, "models-used")
    for model in sorted(metadata["models_used"]):
        ET.SubElement(models_elem, "model").text = model

    messages_elem = ET.SubElement(root, "messages")
    for msg in messages:
        format_message_xml(msg, messages_elem)

    xml_path = export_dir / "conversation.xml"
    xml_string = prettify_xml(root)
    with open(xml_path, "w", encoding="utf-8") as f:
        f.write(xml_string)


# ---------------------------------------------------------------------------
# JSON serialization helper
# ---------------------------------------------------------------------------


def pre_serialize(data):
    if isinstance(data, dict):
        return {k: pre_serialize(v) for k, v in data.items()}
    if isinstance(data, set):
        return sorted(data)
    if isinstance(data, list):
        return [pre_serialize(item) for item in data]
    return data


# ---------------------------------------------------------------------------
# Config snapshot writer
# ---------------------------------------------------------------------------


def _copy_files_to_dir(files: list[Path], dest_dir: Path) -> None:
    if not files:
        return
    dest_dir.mkdir(parents=True, exist_ok=True)
    for f in files:
        shutil.copy2(f, dest_dir / f.name)


def write_config_snapshot(export_dir: Path, config_files: ProjectConfig) -> None:
    config_dir = export_dir / "config"

    _copy_files_to_dir(config_files["commands"], config_dir / "commands")
    _copy_files_to_dir(config_files["skills"], config_dir / "skills")
    _copy_files_to_dir(config_files["hooks"], config_dir / "hooks")
    _copy_files_to_dir(config_files["agents"], config_dir / "agents")
    _copy_files_to_dir(config_files["rules"], config_dir / "rules")

    if config_files["settings"]:
        config_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(config_files["settings"], config_dir / "settings.json")

    if config_files["claude_md"]:
        config_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(config_files["claude_md"], config_dir / "CLAUDE.md")


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------


def export_session(
    session_info: dict,
    project_path: str,
    export_name: str,
    output_dir: Path | None = None,
    output_format: str = "all",
    anonymized: bool = False,
) -> tuple[Path, Manifest]:
    project_path_obj = Path(project_path)

    messages, metadata = parse_jsonl_file(session_info["path"])

    session_id = (
        metadata["session_id"] if metadata["session_id"] else session_info["session_id"]
    )
    slug = None
    for msg in messages:
        if "slug" in msg:
            slug = msg["slug"]
            break

    if output_dir:
        export_dir = output_dir / export_name
    else:
        export_dir = project_path_obj / ".claude-sessions" / export_name

    export_dir.mkdir(parents=True, exist_ok=True)

    # Collect session data
    agent_sessions = collect_agent_sessions(project_path, session_id, messages)
    file_history = collect_file_history(session_id)
    plan_file = collect_plan_file(slug)
    todos = collect_todos(session_id)
    session_env = collect_session_env(session_id)

    session_files = {
        "agents": agent_sessions,
        "file_history": file_history,
        "plan": plan_file,
        "todos": todos,
        "session_env": session_env,
    }

    # Collect project config
    config_files = collect_project_config(project_path)

    # Generate manifest
    manifest = generate_manifest(
        session_id,
        slug,
        export_name,
        metadata,
        messages,
        session_files,
        config_files,
        project_path,
        anonymized,
    )

    # -- Write session data --
    session_dir = export_dir / "session"
    session_dir.mkdir(exist_ok=True)

    shutil.copy2(session_info["path"], session_dir / "main.jsonl")

    if agent_sessions:
        agents_dir = session_dir / "agents"
        agents_dir.mkdir(exist_ok=True)
        for agent_id, agent_path in agent_sessions.items():
            shutil.copy2(agent_path, agents_dir / f"agent-{agent_id}.jsonl")

    if file_history:
        fh_dir = session_dir / "file-history"
        fh_dir.mkdir(exist_ok=True)
        for fh_file in file_history:
            shutil.copy2(fh_file, fh_dir / fh_file.name)

    if plan_file:
        shutil.copy2(plan_file, session_dir / "plan.md")

    if todos:
        all_todos = []
        for todo_file in todos:
            try:
                with open(todo_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        all_todos.extend(data)
                    else:
                        all_todos.append(data)
            except Exception:
                pass
        with open(session_dir / "todos.json", "w", encoding="utf-8") as f:
            json.dump(all_todos, f, indent=2)

    if session_env:
        env_dir = session_dir / "session-env"
        env_dir.mkdir(exist_ok=True)
        for env_file in session_env.iterdir():
            if env_file.is_file():
                shutil.copy2(env_file, env_dir / env_file.name)

    # -- Write config snapshot --
    write_config_snapshot(export_dir, config_files)

    # -- Write conversation files --
    if output_format in ("md", "all"):
        write_conversation_md(export_dir, messages, metadata)

    if output_format in ("xml", "all"):
        write_conversation_xml(export_dir, messages, metadata)

    # -- Write manifest --
    manifest_path = export_dir / ".cctrace-manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(pre_serialize(manifest), f, indent=2)

    # -- Write RENDERED.md --
    rendered_md = generate_rendered_markdown(messages, metadata, manifest)
    with open(export_dir / "RENDERED.md", "w", encoding="utf-8") as f:
        f.write(rendered_md)

    return export_dir, manifest


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def find_session_by_prefix(sessions: list[dict], prefix: str) -> dict | None:
    for session in sessions:
        if session["session_id"] == prefix or session["session_id"].startswith(prefix):
            return session
    return None


def print_export_summary(export_path: Path, manifest: Manifest) -> None:
    sid = manifest["session_id"]
    slug = manifest.get("session_slug")
    label = f"{sid[:8]}..."
    if slug:
        label += f" ({slug})"
    stats = manifest["statistics"]
    agents = len(manifest["session_data"]["agent_sessions"])
    fh = len(manifest["session_data"]["file_history"])
    print(
        f"  {label}: {stats['message_count']} msgs, "
        f"{stats['tool_uses']} tools, "
        f"{agents} agents, "
        f"{fh} file-history snapshots"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export Claude Code sessions to structured directories"
    )
    parser.add_argument(
        "--session",
        dest="session_id",
        help="Export a specific session ID (supports prefix match)",
    )
    parser.add_argument(
        "--latest",
        type=int,
        metavar="N",
        help="Export only the N most recent sessions",
    )
    parser.add_argument(
        "--output-dir",
        help="Custom output directory (default: .claude-sessions/ in project root)",
    )
    parser.add_argument(
        "--format",
        choices=["md", "xml", "all"],
        default="all",
        help="Output format (default: all)",
    )
    parser.add_argument(
        "--export-name",
        help="Custom name for the export directory (only with --session)",
    )
    parser.add_argument(
        "--anonymize",
        action="store_true",
        help="Exclude user/machine info from export",
    )

    args = parser.parse_args()
    cwd = os.getcwd()

    sessions = find_project_sessions(cwd)

    if not sessions:
        print(
            "No Claude Code sessions found for this project.\n"
            "Make sure you're running this from a project directory "
            "with Claude Code session history."
        )
        return 1

    print(f"Found {len(sessions)} session(s) for this project")

    # Determine which sessions to export
    if args.session_id:
        match = find_session_by_prefix(sessions, args.session_id)
        if not match:
            print(f"Session {args.session_id} not found.")
            print("\nAvailable sessions:")
            for s in sessions[:10]:
                print(f"  {s['session_id']}")
            return 1
        sessions_to_export = [match]
    elif args.latest:
        sessions_to_export = sessions[: args.latest]
    else:
        sessions_to_export = sessions

    output_dir = Path(args.output_dir) if args.output_dir else None

    print(f"Exporting {len(sessions_to_export)} session(s)...\n")

    exported = 0
    failed = 0
    for session_info in sessions_to_export:
        export_name = (
            args.export_name
            if args.export_name and len(sessions_to_export) == 1
            else session_info["session_id"]
        )
        try:
            export_path, manifest = export_session(
                session_info,
                cwd,
                export_name,
                output_dir=output_dir,
                output_format=args.format,
                anonymized=args.anonymize,
            )
            print_export_summary(export_path, manifest)
            exported += 1
        except Exception as e:
            print(f"  {session_info['session_id'][:8]}...: FAILED ({e})")
            failed += 1

    out_location = output_dir or Path(cwd) / ".claude-sessions"
    print(f"\nExported {exported} session(s) to {out_location}")
    if failed:
        print(f"{failed} session(s) failed")

    return 1 if failed and not exported else 0


if __name__ == "__main__":
    sys.exit(main())

# vim: syn=python ft=python
