#!/usr/bin/env bash
set -euo pipefail

TARGET="$HOME/.devcontainer-socket.sock"
rm -f "$TARGET"

if [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock" ]; then
  echo "Detected Podman socket"
  ln -s "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock" "$TARGET"
elif [ -S "/var/run/docker.sock" ]; then
  echo "Detected Docker socket"
  ln -s "/var/run/docker.sock" "$TARGET"
else
  echo "No container socket found at expected paths" >&2
  exit 1
fi
