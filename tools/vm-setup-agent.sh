#!/bin/bash
# Run INSIDE the VM (as admin, which has passwordless sudo on the Cirrus images).
# Installs tart-guest-agent so `tart exec` works, and enables it at boot/login.
set -euo pipefail
SRC="/Volumes/My Shared Files/vm-tools/tart-guest-agent"
[[ -f "$SRC" ]] || { echo "agent binary not found at $SRC" >&2; exit 1; }

sudo mkdir -p /usr/local/bin
sudo install -m 755 "$SRC" /usr/local/bin/tart-guest-agent
sudo xattr -c /usr/local/bin/tart-guest-agent 2>/dev/null || true

plist() { # label, flag, file
  sudo tee "$3" >/dev/null <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$1</string>
  <key>ProgramArguments</key><array><string>/usr/local/bin/tart-guest-agent</string><string>$2</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/$1.log</string>
  <key>StandardErrorPath</key><string>/tmp/$1.log</string>
</dict></plist>
PL
  sudo chown root:wheel "$3"; sudo chmod 644 "$3"
}
plist org.cirruslabs.tart-guest-agent.daemon --run-daemon /Library/LaunchDaemons/org.cirruslabs.tart-guest-agent.daemon.plist
plist org.cirruslabs.tart-guest-agent.agent  --run-agent  /Library/LaunchAgents/org.cirruslabs.tart-guest-agent.agent.plist

sudo launchctl bootout system /Library/LaunchDaemons/org.cirruslabs.tart-guest-agent.daemon.plist 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/org.cirruslabs.tart-guest-agent.daemon.plist
UIDN=$(id -u)
sudo launchctl bootout "gui/$UIDN" /Library/LaunchAgents/org.cirruslabs.tart-guest-agent.agent.plist 2>/dev/null || true
sudo launchctl bootstrap "gui/$UIDN" /Library/LaunchAgents/org.cirruslabs.tart-guest-agent.agent.plist 2>&1 || \
  echo "note: no GUI session yet; the agent will start at next login"
echo "guest agent installed"
