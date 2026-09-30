#!/bin/bash
# Installs airvm: Tart + guest agent (checksum-verified), the airvm CLI, and an SSH key/alias for the VM.
# Idempotent. Everything goes under ~/.local and ~/.ssh; no sudo needed on the host.
set -euo pipefail

TART_VERSION="2.32.1"
TART_SHA256="8554ab4f7fc12afe52f9b7e3093a935673cbac737a83973d2db7a0683c814529"
AGENT_VERSION="0.10.0"
AGENT_SHA256="303a50d452753e36776ce8775e243be580bb3fc3ec8efde154320c37fd65b1a7"

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"; OPT="$HOME/.local/opt"; TOOLS="$HOME/.local/share/air-vm/tools"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$BIN" "$OPT/tart" "$TOOLS" "$HOME/.local/log"

fetch() { # url sha256 out
  curl -fsSL -o "$3" "$1"
  echo "$2  $3" | shasum -a 256 -c - >/dev/null || { echo "checksum mismatch for $1" >&2; exit 1; }
}

if [[ ! -x "$BIN/tart" ]]; then
  echo "installing tart $TART_VERSION"
  fetch "https://github.com/cirruslabs/tart/releases/download/$TART_VERSION/tart.tar.gz" "$TART_SHA256" "$TMP/tart.tar.gz"
  tar -xzf "$TMP/tart.tar.gz" -C "$OPT/tart"
  ln -sf "$OPT/tart/tart.app/Contents/MacOS/tart" "$BIN/tart"
else echo "tart already installed"; fi

if [[ ! -x "$TOOLS/tart-guest-agent" ]]; then
  echo "fetching tart-guest-agent $AGENT_VERSION"
  fetch "https://github.com/cirruslabs/tart-guest-agent/releases/download/v$AGENT_VERSION/tart-guest-agent-darwin-all.tar.gz" "$AGENT_SHA256" "$TMP/tga.tar.gz"
  tar -xzf "$TMP/tga.tar.gz" -C "$TMP"; install -m 755 "$TMP/tart-guest-agent" "$TOOLS/tart-guest-agent"
fi

install -m 755 "$HERE/bin/airvm" "$BIN/airvm"
install -m 755 "$HERE/tools/"*.sh "$TOOLS/"

mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
if [[ ! -f "$HOME/.ssh/air-vm" ]]; then
  ssh-keygen -q -t ed25519 -N "" -C "air-vm local tart key" -f "$HOME/.ssh/air-vm"
fi
touch "$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"
if ! grep -q '^Host air-vm$' "$HOME/.ssh/config"; then
  cat >> "$HOME/.ssh/config" <<'CFG'

# air-vm: local Tart VM (added by airvm install.sh)
Host air-vm
  User admin
  IdentityFile ~/.ssh/air-vm
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  UserKnownHostsFile ~/.ssh/known_hosts.air-vm
  ProxyCommand sh -c 'nc $(~/.local/bin/tart ip air-vm --wait 60) %p'
CFG
fi

case ":$PATH:" in *":$BIN:"*) ;; *) echo "note: add $BIN to your PATH";; esac
echo "done. Next: see README.md (pull the image, boot, authorize the key)."
