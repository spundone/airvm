# airvm

Small helper around [Tart](https://tart.run) for a local macOS VM that mirrors a laptop's
environment (files, Homebrew set, tooling), so there is a runnable copy if the laptop dies.

Host: Apple silicon Mac. Guest: a Cirrus Labs vanilla macOS image.

## Install

```bash
./install.sh            # tart + guest agent (checksum-verified), airvm CLI, ssh key + alias
```

Needs `~/.local/bin` on your PATH. Nothing is committed here that is machine- or person-specific:
no keys, no backups, no binaries.

## Create the VM (one time)

```bash
tart clone ghcr.io/cirruslabs/macos-tahoe-vanilla:latest air-vm    # ~24 GB download
airvm up
ssh-copy-id -i ~/.ssh/air-vm.pub air-vm    # type the image's default password once
airvm setup-agent                          # installs tart-guest-agent so `tart exec` works
airvm restore                              # restore a backup + Brewfile inside the VM
```

`airvm up` shares two folders into the guest, read-only, at `/Volumes/My Shared Files/`:

| share | host path |
|---|---|
| `air-backup` | `~/air-backup` (a backup made with rsync; expects `backup-*/` dirs with an `air-env/Brewfile`) |
| `vm-tools` | `~/.local/share/air-vm/tools` |

The default login of the vanilla image is well known. Change it if you keep the VM.

## Commands

```
airvm up | down | status | ip
airvm ssh [cmd]            ssh in (key auth)
airvm exec <cmd>           run via tart exec (falls back to ssh)
airvm push <src> [dst]     copy to the VM;  airvm pull <remote> [dst]  copy back
airvm restore              run the restore script in the VM
airvm setup-agent          install tart-guest-agent (enables tart exec)
airvm gui                  open the VM desktop in macOS Screen Sharing (alias: vnc)
airvm open <app|path|url>  launch a GUI app or URL on the VM desktop
airvm shot [file]          screenshot the VM desktop (needs Screen Recording granted in the VM)
airvm snap <name>          clone the stopped VM as a snapshot;  airvm snaps  to list
```

Restore a snapshot: `tart delete air-vm && tart clone air-vm-<name> air-vm`.

## Notes

- `airvm up` starts the VM headless (`--no-graphics`). Use `airvm gui` to see it.
- Jamf/MDM enrolment, Touch ID and hardware-tied licences do not carry over into a VM.
- `tools/air-vm-restore.sh` skips a few casks that make no sense in a VM (edit the `grep -vE` line).
- Homebrew 7's `cirruslabs/cli/tart` formula failed at time of writing, hence the direct release install.
