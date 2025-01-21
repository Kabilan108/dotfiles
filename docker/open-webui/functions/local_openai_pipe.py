"""
title: Local OpenAI-Compatible Server Pipe
version: 0.1.0
required_open_webui_version: 0.3.17
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
        BASE_URL: str = Field(default="http://localhost:8000")
        API_KEY: str = Field(default="")

    def __init__(self):
        self.type = "manifold"
        self.id = "local_openai"
        self.name = "local/"
        self.valves = self.Valves(
            **{
                "BASE_URL": os.getenv("LOCAL_AI_BASE_URL", "http://localhost:8000"),
                "API_KEY": os.getenv("LOCAL_AI_API_KEY", ""),
            }
        )

    def get_local_models(self):
        return [
            {"id": "deepseek/r1-distill-llama-8b", "name": "r1-llama-8b"},
        ]

    def pipes(self) -> List[dict]:
        return self.get_local_models()

    def get_headers(self):
        headers = {"Content-Type": "application/json"}
        if self.valves.API_KEY:
            headers["Authorization"] = f"Bearer {self.valves.API_KEY}"
        return headers

    def pipe(self, body: dict) -> Union[str, Generator, Iterator]:
        system_message, messages = pop_system_message(body["messages"])
        if system_message:
            messages.insert(0, {"role": "system", "content": system_message})

        payload = {
            "model": body["model"][body["model"].find(".") + 1 :],
            "messages": messages,
            "max_tokens": body.get("max_tokens", 4096),
            "temperature": body.get("temperature", 0.8),
            "top_p": body.get("top_p", 0.9),
            "stream": body.get("stream", False),
        }

        url = f"{self.valves.BASE_URL}/v1/chat/completions"

        try:
            if body.get("stream", False):
                return self.stream_response(url, self.get_headers(), payload)
            else:
                return self.non_stream_response(url, self.get_headers(), payload)
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
                                if "choices" in data and len(data["choices"]) > 0:
                                    delta = data["choices"][0].get("delta", {})
                                    if "content" in delta:
                                        yield delta["content"]
                                time.sleep(0.01)
                            except json.JSONDecodeError:
                                print(f"Failed to parse JSON: {line}")
                            except KeyError as e:
                                print(f"Unexpected data structure: {e}")
                                print(f"Full data: {data}")
        except Exception as e:
            print(f"Error in stream_response: {e}")
            yield f"Error: {e}"

    def non_stream_response(self, url, headers, payload):
        try:
            response = requests.post(
                url, headers=headers, json=payload, timeout=(3.05, 60)
            )
            if response.status_code != 200:
                raise Exception(f"HTTP Error {response.status_code}: {response.text}")

            res = response.json()
            return res["choices"][0]["message"]["content"] if "choices" in res else ""
        except requests.exceptions.RequestException as e:
            print(f"Failed non-stream request: {e}")
            return f"Error: {e}"
