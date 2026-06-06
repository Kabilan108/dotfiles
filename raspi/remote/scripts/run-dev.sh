#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

if [[ ! -f .remote-token ]]; then
  umask 077
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24 > .remote-token
  else
    date +%s%N | sha256sum | cut -d' ' -f1 > .remote-token
  fi
fi

python_bin=${PYTHON:-}
if [[ -z "$python_bin" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python_bin=python3
  elif [[ -x /nix/store/lqn6mbgzzdrqq2qkwddcmxj9z6amdd86-python3-3.13.13/bin/python ]]; then
    python_bin=/nix/store/lqn6mbgzzdrqq2qkwddcmxj9z6amdd86-python3-3.13.13/bin/python
  else
    echo "python3 not found. Try: nix develop -c ./scripts/run-dev.sh" >&2
    exit 1
  fi
fi

exec "$python_bin" server.py
