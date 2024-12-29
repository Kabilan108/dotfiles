#! /bin/bash

set -e

if [ ! -f /config/.initialized ]; then
  curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /config/yt-dlp
  chmod a+rx /config/yt-dlp
  apt update && apt install -y --no-install-recommends --no-install-suggests python3
  touch /config/.initialized
fi

export PATH="/config:$PATH"
exec /jellyfin/jellyfin
