"""
title: Anthropic Manifold Pipe
authors: justinh-rahb and christian-taillon
author_url: https://github.com/justinh-rahb
funding_url: https://github.com/open-webui
version: 0.2.4
required_open_webui_version: 0.3.17
license: MIT
"""

import os
import requests
import json
import time
from typing import List, Union, Generator, Iterator
from pydantic import BaseModel, Field
from open_webui.utils.misc import pop_system_message


class Pipe:
    class Valves(BaseModel):
        ANTHROPIC_API_KEY: str = Field(default="")

    def __init__(self):
        self.type = "manifold"
        self.id = "anthropic"
        self.name = "anthropic/"
        self.valves = self.Valves(
            **{"ANTHROPIC_API_KEY": os.getenv("ANTHROPIC_API_KEY", "")}
        )
        self.MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5MB per image
        self.CACHE_SUPPORTED_MODELS = [
            "claude-3-5-sonnet-20241022",
            "claude-3-opus-20240229",
            "claude-3-5-haiku-latest",
            "claude-3-haiku-20240307",
        ]

    def model_supports_caching(self, model_id: str) -> bool:
        return any(
            model_id.startswith(m.split("-2024")[0])
            for m in self.CACHE_SUPPORTED_MODELS
        )

    def get_min_cache_tokens(self, model_id: str) -> int:
        if "sonnet" in model_id or "opus" in model_id:
            return 1024
        elif "haiku" in model_id:
            return 2048
        return 0

    def get_anthropic_models(self):
        return [
            {"id": "claude-3-5-sonnet-20241022", "name": "claude-3.5-sonnet"},
            {"id": "claude-3-opus-20240229", "name": "claude-3-opus"},
            {"id": "claude-3-5-haiku-latest", "name": "claude-3.5-haiku"},
        ]

    def pipes(self) -> List[dict]:
        return self.get_anthropic_models()

    def process_image(self, image_data):
        """Process image data with size validation."""
        if image_data["image_url"]["url"].startswith("data:image"):
            mime_type, base64_data = image_data["image_url"]["url"].split(",", 1)
            media_type = mime_type.split(":")[1].split(";")[0]
            image_size = len(base64_data) * 3 // 4
            if image_size > self.MAX_IMAGE_SIZE:
                raise ValueError(
                    f"Image size exceeds 5MB limit: {image_size / (1024 * 1024):.2f}MB"
                )
            return {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": base64_data,
                },
            }
        else:
            url = image_data["image_url"]["url"]
            response = requests.head(url, allow_redirects=True)
            content_length = int(response.headers.get("content-length", 0))
            if content_length > self.MAX_IMAGE_SIZE:
                raise ValueError(
                    f"Image at URL exceeds 5MB limit: {content_length / (1024 * 1024):.2f}MB"
                )
            return {
                "type": "image",
                "source": {"type": "url", "url": url},
            }

    def pipe(self, body: dict) -> Union[str, Generator, Iterator]:
        system_message, messages = pop_system_message(body["messages"])
        model_id = body["model"][body["model"].find(".") + 1 :]
        supports_caching = self.model_supports_caching(model_id)
        min_tokens = self.get_min_cache_tokens(model_id)
        min_chars = min_tokens * 4  # Approximate token-to-char ratio

        # Process system message
        system_blocks = []
        if system_message:
            system_text = str(system_message)
            system_block = {"type": "text", "text": system_text}
            if supports_caching and len(system_text) >= min_chars:
                system_block["cache_control"] = {"type": "ephemeral"}
            system_blocks.append(system_block)

        # Process messages and images
        processed_messages = []
        total_image_size = 0
        for message in messages:
            processed_content = []
            if isinstance(message.get("content"), list):
                for item in message["content"]:
                    if item["type"] == "text":
                        text = item["text"]
                        new_item = {"type": "text", "text": text}
                        if supports_caching and len(text) >= min_chars:
                            new_item["cache_control"] = {"type": "ephemeral"}
                        processed_content.append(new_item)
                    elif item["type"] == "image_url":
                        processed_image = self.process_image(item)
                        if supports_caching:
                            processed_image["cache_control"] = {"type": "ephemeral"}
                        if processed_image["source"]["type"] == "base64":
                            image_size = len(processed_image["source"]["data"]) * 3 // 4
                            total_image_size += image_size
                            if total_image_size > 100 * 1024 * 1024:
                                raise ValueError(
                                    "Total image size exceeds 100 MB limit"
                                )
                        processed_content.append(processed_image)
            else:
                text = message.get("content", "")
                new_item = {"type": "text", "text": text}
                if supports_caching and len(text) >= min_chars:
                    new_item["cache_control"] = {"type": "ephemeral"}
                processed_content = [new_item]
            processed_messages.append(
                {"role": message["role"], "content": processed_content}
            )

        payload = {
            "model": model_id,
            "messages": processed_messages,
            "max_tokens": body.get("max_tokens", 4096),
            "temperature": body.get("temperature", 0.8),
            "top_k": body.get("top_k", 40),
            "top_p": body.get("top_p", 0.9),
            "stop_sequences": body.get("stop", []),
            **({"system": system_blocks} if system_blocks else {}),
            "stream": body.get("stream", False),
        }

        headers = {
            "x-api-key": self.valves.ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        url = "https://api.anthropic.com/v1/messages"

        try:
            if body.get("stream", False):
                return self.stream_response(url, headers, payload)
            else:
                return self.non_stream_response(url, headers, payload)
        except requests.exceptions.RequestException as e:
            print(f"Request failed: {e}")
            return f"Error: Request failed: {e}"
        except Exception as e:
            print(f"Error in pipe method: {e}")
            return f"Error: {e}"

    def stream_response(self, url, headers, payload):
        try:
            with requests.post(
                url, headers=headers, json=payload, stream=True, timeout=(3.05, 60)
            ) as response:
                if response.status_code != 200:
                    raise Exception(
                        f"HTTP Error {response.status_code}: {response.text}"
                    )
                for line in response.iter_lines():
                    if line:
                        line = line.decode("utf-8")
                        if line.startswith("data: "):
                            try:
                                data = json.loads(line[6:])
                                if data["type"] == "content_block_start":
                                    yield data["content_block"]["text"]
                                elif data["type"] == "content_block_delta":
                                    yield data["delta"]["text"]
                                elif data["type"] == "message_stop":
                                    break
                                elif data["type"] == "message":
                                    for content in data.get("content", []):
                                        if content["type"] == "text":
                                            yield content["text"]
                                time.sleep(0.01)
                            except json.JSONDecodeError:
                                print(f"Failed to parse JSON: {line}")
                            except KeyError as e:
                                print(f"Unexpected data structure: {e}")
                                print(f"Full data: {data}")
        except requests.exceptions.RequestException as e:
            print(f"Request failed: {e}")
            yield f"Error: Request failed: {e}"
        except Exception as e:
            print(f"General error in stream_response method: {e}")
            yield f"Error: {e}"

    def non_stream_response(self, url, headers, payload):
        try:
            response = requests.post(
                url, headers=headers, json=payload, timeout=(3.05, 60)
            )
            if response.status_code != 200:
                raise Exception(f"HTTP Error {response.status_code}: {response.text}")
            res = response.json()
            return (
                res["content"][0]["text"] if "content" in res and res["content"] else ""
            )
        except requests.exceptions.RequestException as e:
            print(f"Failed non-stream request: {e}")
            return f"Error: {e}"
