#!/bin/bash
# Run INSIDE the VM. Restores the Air backup (shared into the VM read-only) and rebuilds the toolchain.
# The backup is mounted by `tart run --dir=air-backup:...:ro` at /Volumes/My Shared Files/air-backup.
set -uo pipefail

SRC="/Volumes/My Shared Files/air-backup"
LATEST="$(ls -d "$SRC"/backup-* 2>/dev/null | tail -1)"
[[ -d "$LATEST" ]] || { echo "backup not found under $SRC" >&2; exit 1; }
echo "restoring from: $LATEST"

# 1. user files and config (never overwrite existing files in the VM)
for p in Desktop Documents Downloads .config .claude .gitconfig .aws .kube; do
  [[ -e "$LATEST/$p" ]] && rsync -a --ignore-existing "$LATEST/$p" "$HOME/"
done
# .ssh with correct perms
if [[ -d "$LATEST/.ssh" ]]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  rsync -a --ignore-existing --exclude=agent "$LATEST/.ssh/" "$HOME/.ssh/"
  chmod 600 "$HOME"/.ssh/* 2>/dev/null
fi

# 2. Homebrew, then everything from the Air's Brewfile
if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"

BREWFILE="$LATEST/air-env/Brewfile"
if [[ -f "$BREWFILE" ]]; then
  # skip casks that are pointless or interactive in a VM
  grep -vE 'wispr-flow|whatsapp|stats|lidanglesensor' "$BREWFILE" > /tmp/Brewfile.vm
  brew bundle --file=/tmp/Brewfile.vm
fi

echo "done. Sign in to gh, aws sso, Slack, etc. inside the VM as needed."
