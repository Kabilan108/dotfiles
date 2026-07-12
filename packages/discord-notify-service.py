#!/usr/bin/env python3

import argparse
import json
import os
import re
import secrets
import ssl
import sys
import urllib.error
import urllib.request
from datetime import UTC, datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, ClassVar


CHANNEL_ENV_PATTERN = re.compile(r"^DISCORD_CHANNEL_([A-Z0-9_]+)_WEBHOOK_URL$")
CHANNEL_NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
STATUS_COLORS = {
    "info": 3447003,
    "success": 65280,
    "warning": 16776960,
    "error": 10181038,
}


def configured_channels(environment: dict[str, str]) -> dict[str, str]:
    channels: dict[str, str] = {}
    for name, webhook_url in environment.items():
        match = CHANNEL_ENV_PATTERN.fullmatch(name)
        if not match or not webhook_url.strip():
            continue
        channel = match.group(1).lower().replace("_", "-")
        if not CHANNEL_NAME_PATTERN.fullmatch(channel):
            raise ValueError(f"invalid channel name derived from {name}")
        channels[channel] = webhook_url.strip()
    return channels


def make_payload(message: dict[str, Any], channel: str) -> dict[str, Any]:
    title = require_string(message, "title", 1, 256)
    body = optional_string(message, "body", 4096)
    source = optional_string(message, "source", 256)
    status = message.get("status", "info")
    if status not in STATUS_COLORS:
        raise ValueError(f"status must be one of: {', '.join(STATUS_COLORS)}")

    embed: dict[str, Any] = {
        "title": title,
        "color": STATUS_COLORS[status],
        "footer": {"text": f"Agent notification · {channel}"},
        "timestamp": datetime.now(UTC).isoformat(),
    }
    if body:
        embed["description"] = body
    if source:
        embed["fields"] = [{"name": "Source", "value": source, "inline": True}]

    return {
        "allowed_mentions": {"parse": []},
        "embeds": [embed],
        "username": "Agent Notifications",
    }


def require_string(value: dict[str, Any], key: str, minimum: int, maximum: int) -> str:
    result = value.get(key)
    if not isinstance(result, str):
        raise ValueError(f"{key} must be a string")
    result = result.strip()
    if not minimum <= len(result) <= maximum:
        raise ValueError(f"{key} must contain between {minimum} and {maximum} characters")
    return result


def optional_string(value: dict[str, Any], key: str, maximum: int) -> str | None:
    result = value.get(key)
    if result is None:
        return None
    if not isinstance(result, str):
        raise ValueError(f"{key} must be a string")
    result = result.strip()
    if len(result) > maximum:
        raise ValueError(f"{key} must contain at most {maximum} characters")
    return result or None


def post_webhook(webhook_url: str, payload: dict[str, Any]) -> None:
    request = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload).encode(),
        headers={
            "content-type": "application/json",
            "user-agent": "discord-notify-service/1.0",
        },
        method="POST",
    )
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(request, timeout=20, context=context) as response:
            response.read()
    except urllib.error.HTTPError as exc:
        exc.read()
        raise RuntimeError(f"Discord rejected the notification with HTTP {exc.code}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError("Discord could not be reached") from exc


def openapi_document() -> dict[str, Any]:
    message_schema = {
        "type": "object",
        "additionalProperties": False,
        "required": ["channel", "title"],
        "properties": {
            "channel": {
                "type": "string",
                "description": "A channel name returned by listChannels.",
                "pattern": CHANNEL_NAME_PATTERN.pattern,
            },
            "title": {"type": "string", "minLength": 1, "maxLength": 256},
            "body": {"type": "string", "maxLength": 4096},
            "status": {
                "type": "string",
                "enum": list(STATUS_COLORS),
                "default": "info",
            },
            "source": {
                "type": "string",
                "maxLength": 256,
                "description": "The workflow or agent sending the notification.",
            },
        },
    }
    return {
        "openapi": "3.1.0",
        "info": {
            "title": "Discord Notify",
            "version": "1.0.0",
            "description": "Send notifications to a fixed set of configured Discord channels.",
        },
        "servers": [{"url": "/"}],
        "components": {
            "securitySchemes": {
                "bearerAuth": {"type": "http", "scheme": "bearer"},
            },
            "schemas": {"Message": message_schema},
        },
        "security": [{"bearerAuth": []}],
        "paths": {
            "/channels": {
                "get": {
                    "operationId": "listChannels",
                    "summary": "List configured notification channel names",
                    "responses": {
                        "200": {
                            "description": "Configured channel names",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {
                                            "channels": {
                                                "type": "array",
                                                "items": {"type": "string"},
                                            }
                                        },
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/messages": {
                "post": {
                    "operationId": "sendNotification",
                    "summary": "Send a notification to a configured Discord channel",
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/Message"}
                            }
                        },
                    },
                    "responses": {
                        "202": {"description": "Notification delivered to Discord"},
                        "404": {"description": "Channel is not configured"},
                    },
                }
            },
        },
    }


class NotifyHandler(BaseHTTPRequestHandler):
    api_token: ClassVar[str]
    channels: ClassVar[dict[str, str]]

    def do_GET(self) -> None:
        if self.path == "/health":
            self.respond(HTTPStatus.OK, {"status": "ok"})
            return
        if self.path == "/openapi.json":
            self.respond(HTTPStatus.OK, openapi_document())
            return
        if self.path != "/channels":
            self.respond(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        if not self.authorized():
            return
        self.respond(HTTPStatus.OK, {"channels": sorted(self.channels)})

    def do_POST(self) -> None:
        if self.path != "/messages":
            self.respond(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        if not self.authorized():
            return
        try:
            length = int(self.headers.get("content-length", "0"))
            if length > 16384:
                raise ValueError("request body is too large")
            message = json.loads(self.rfile.read(length))
            if not isinstance(message, dict):
                raise ValueError("request body must be an object")
            channel = require_string(message, "channel", 1, 32)
            webhook_url = self.channels.get(channel)
            if webhook_url is None:
                self.respond(HTTPStatus.NOT_FOUND, {"error": "channel is not configured"})
                return
            post_webhook(webhook_url, make_payload(message, channel))
        except (json.JSONDecodeError, ValueError) as exc:
            self.respond(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
            return
        except RuntimeError as exc:
            self.respond(HTTPStatus.BAD_GATEWAY, {"error": str(exc)})
            return
        self.respond(HTTPStatus.ACCEPTED, {"status": "sent", "channel": channel})

    def authorized(self) -> bool:
        supplied = self.headers.get("authorization", "")
        expected = f"Bearer {self.api_token}"
        if secrets.compare_digest(supplied, expected):
            return True
        self.send_response(HTTPStatus.UNAUTHORIZED)
        self.send_header("content-type", "application/json")
        self.send_header("www-authenticate", "Bearer")
        self.end_headers()
        self.wfile.write(b'{"error":"unauthorized"}')
        return False

    def respond(self, status: HTTPStatus, value: dict[str, Any]) -> None:
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: Any) -> None:
        print(f"{self.address_string()} {format % args}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8303)
    args = parser.parse_args()

    api_token = os.environ.get("DISCORD_NOTIFY_API_TOKEN", "").strip()
    channels = configured_channels(dict(os.environ))
    if not api_token:
        parser.error("DISCORD_NOTIFY_API_TOKEN is required")
    if not channels:
        parser.error("at least one DISCORD_CHANNEL_<NAME>_WEBHOOK_URL is required")

    NotifyHandler.api_token = api_token
    NotifyHandler.channels = channels
    server = ThreadingHTTPServer((args.host, args.port), NotifyHandler)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
