#!/usr/bin/env bash

set -euo pipefail

IMAGE_NAME="linux-privesc-ctf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[+] Building CTF container..."
docker build -t "$IMAGE_NAME" .

echo
echo "[+] Starting challenge."
echo "[+] You will be logged in as the unprivileged 'ctf' user."
echo

exec docker run \
    --rm \
    -it \
    --name linux-privesc-ctf \
    "$IMAGE_NAME"
