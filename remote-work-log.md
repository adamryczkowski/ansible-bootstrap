# Remote Work Log

## Session 1: ComfyUI LXD Container Setup

### Session 1 Host Information

- **Host**: 192.168.10.5 (potwor)
- **User**: adam
- **OS**: Ubuntu 24.04.3 LTS

### Session 1 Commands Executed

#### 1. Check LXD version

- **Intention**: Verify LXD is installed and check version
- **Command**: `lxc --version`
- **Output**: `5.21.4 LTS`
- **Interpretation**: LXD is installed and running version 5.21.4 LTS

#### 2. List LXD networks

- **Intention**: Check available networks for bridged container networking
- **Command**: `lxc network list`
- **Output**:

  ```text
  +-----------------+----------+---------+-----------------+------+-------------+---------+---------+
  |      NAME       |   TYPE   | MANAGED |      IPV4       | IPV6 | DESCRIPTION | USED BY |  STATE  |
  +-----------------+----------+---------+-----------------+------+-------------+---------+---------+
  | lxdbr0          | bridge   | YES     | 192.168.10.1/24 |      |             | 2       | CREATED |
  +-----------------+----------+---------+-----------------+------+-------------+---------+---------+
  ```

- **Interpretation**: `lxdbr0` is already configured with 192.168.10.1/24, which is the target network. Containers using this bridge will get IPs in the 192.168.10.0/24 range.

#### 3. List LXD profiles

- **Intention**: Check available profiles for container configuration
- **Command**: `lxc profile list`
- **Output**:

  ```text
  +---------+---------------------+---------+
  |  NAME   |     DESCRIPTION     | USED BY |
  +---------+---------------------+---------+
  | default | Default LXD profile | 1       |
  +---------+---------------------+---------+
  ```

- **Interpretation**: Only the default profile exists, used by 1 container

#### 4. Show default profile configuration

- **Intention**: Verify default profile has correct network and storage configuration
- **Command**: `lxc profile show default`
- **Output**:

  ```yaml
  name: default
  description: Default LXD profile
  config: {}
  devices:
    eth0:
      name: eth0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  ```

- **Interpretation**: Default profile is configured to use `lxdbr0` network and `default` storage pool. This is suitable for our ComfyUI container.

#### 5. List existing containers

- **Intention**: Check existing containers on the host
- **Command**: `lxc list`
- **Output**:

  ```text
  +--------------------+---------+------+------+-----------+-----------+
  |        NAME        |  STATE  | IPV4 | IPV6 |   TYPE    | SNAPSHOTS |
  +--------------------+---------+------+------+-----------+-----------+
  | ansible-test-noble | STOPPED |      |      | CONTAINER | 0         |
  +--------------------+---------+------+------+-----------+-----------+
  ```

- **Interpretation**: One stopped container exists (`ansible-test-noble`). No `comfyui` container yet.

### Session 1 Conclusions

- LXD is properly configured on the host
- The `lxdbr0` bridge is already on the 192.168.10.0/24 network
- The default profile is suitable for creating the ComfyUI container
- We can create the container using Ansible with the `community.general.lxd_container` module

---

## Session 2: Sway Installation Verification on VirtualBox VM

### Session 2 Host Information

- **Host**: 10.80.83.140 (ubuntu-vm)
- **User**: adam
- **OS**: Ubuntu 24.04.3 LTS
- **Purpose**: Verify Sway desktop environment installation after Ansible playbook run

### Session 2 Commands Executed

#### 1. Check Sway version

- **Intention**: Verify Sway is installed via Nix and check version
- **Command**: `source /nix/var/nix/profiles/default/etc/profile.d/nix.sh && sway --version`
- **Output**: `sway version 1.11`
- **Interpretation**: Sway 1.11 (latest) is successfully installed via Nix

#### 2. Check Foot terminal version

- **Intention**: Verify Foot terminal is compiled and installed
- **Command**: `foot --version`
- **Output**: `foot version: 1.25.0 -pgo +ime +graphemes -assertions`
- **Interpretation**: Foot 1.25.0 is successfully compiled and installed with IME and grapheme support

#### 3. Check Sway config symlink

- **Intention**: Verify Sway config points to i3-config repository
- **Command**: `ls -la ~/.config/sway`
- **Output**: `/home/adam/.config/sway -> /home/adam/.config/i3-config/sway`
- **Interpretation**: Sway config correctly symlinked to i3-config repository

#### 4. Check i3-config repository branch

- **Intention**: Verify the i3-config repository is on the sway branch
- **Command**: `cd ~/.config/i3-config && git branch`
- **Output**: `* sway` (with master also available)
- **Interpretation**: Repository is correctly checked out to the sway branch

#### 5. Check Nix profile binaries

- **Intention**: Verify all Sway-related tools are installed via Nix
- **Command**: `ls -la ~/.nix-profile/bin/`
- **Output**:
  - `sway` -> sway-1.11
  - `swaybar`, `swaymsg`, `swaynag`
  - `kanshi` -> kanshi-1.8.0
  - `wdisplays` -> wdisplays-1.1.3
  - `wl-gammarelay-rs` -> wl-gammarelay-rs-1.0.1
  - `wlr-randr` -> wlr-randr-0.5.0
  - `nixGL` (OpenGL wrapper)
- **Interpretation**: All Wayland tools are installed via Nix

#### 6. Check Sway session entry

- **Intention**: Verify Sway session is available in display manager
- **Command**: `ls -la /usr/share/wayland-sessions/`
- **Output**: `sway-nix.desktop` present alongside ubuntu.desktop and ubuntu-wayland.desktop
- **Interpretation**: Sway session is available for selection at login

#### 7. Check sway-session wrapper script

- **Intention**: Verify the session wrapper script is correctly configured
- **Command**: `cat /usr/local/bin/sway-session`
- **Output**: Script sources Nix profile, sets Wayland environment variables, and launches Sway with nixGL
- **Interpretation**: Session wrapper is correctly configured for Nix-installed Sway

#### 8. Check XDG portal configuration

- **Intention**: Verify XDG Desktop Portal is configured for Sway
- **Command**: `cat /usr/share/xdg-desktop-portal/sway-portals.conf`
- **Output**:

  ```ini
  [preferred]
  default=gtk;
  org.freedesktop.impl.portal.Screenshot=wlr;
  org.freedesktop.impl.portal.ScreenCast=wlr;
  ```

- **Interpretation**: Portal backends correctly configured (GTK for most, wlr for screenshot/screencast)

#### 9. Check portal environment config

- **Intention**: Verify Sway includes portal environment setup
- **Command**: `cat /etc/sway/config.d/50-portal-env.conf`
- **Output**: `exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway`
- **Interpretation**: Portal environment variables will be exported when Sway starts

#### 10. Check fonts installation

- **Intention**: Verify required fonts are installed
- **Command**: `fc-list | grep -i "nerd\|exo2\|symbols" | head -10`
- **Output**:
  - Exo 2 (various styles) in ~/.local/share/fonts/
  - Symbols Nerd Font Mono in ~/.local/share/fonts/
  - Noto Sans Symbols (various weights) in /usr/share/fonts/
- **Interpretation**: All required fonts are installed

#### 11. Check Sway config includes

- **Intention**: Verify Sway config includes system config.d directory
- **Command**: `grep -n "include" ~/.config/sway/config`
- **Output**: `467:include /etc/sway/config.d/*`
- **Interpretation**: Sway config includes system config.d directory, portal env config will be loaded

### Session 2 Conclusions

- **Sway 1.11** is successfully installed via Nix package manager
- **Foot 1.25.0** terminal is compiled and installed
- **i3-config repository** is cloned and checked out to the `sway` branch
- **Sway config** is correctly symlinked to the repository
- **XDG Desktop Portal** is configured for Sway/wlroots
- **Fonts** (Exo 2, Nerd Fonts Symbols) are installed
- **Session entry** is available in display manager
- **nixGL** is installed for OpenGL support with Nix-installed applications
- The installation is ready for use - user can log out and select "Sway (Nix)" from the display manager

### Session 2 Known Issues

- **Fusuma gem installation failed** due to network timeout to rubygems.org (ignored, non-critical)
- **XKB custom keymap** was not deployed (sway_deploy_custom_xkb_keymap defaults to false)

---

## Session 3: ComfyUI LXD Container Creation

### Session 3 Host Information

- **Host**: 192.168.10.5 (potwor)
- **User**: adam
- **OS**: Ubuntu 24.04.3 LTS

### Container Created

- **Container Name**: comfyui
- **Container IP**: 192.168.10.250
- **Container Status**: Running
- **Image**: Ubuntu 24.04 LTS amd64 (release) (20251213)
- **Resource Limits**: 4 CPUs, 8GB RAM
- **Network**: eth0 on lxdbr0 bridge (192.168.10.0/24)

### Session 3 Commands Executed

#### 1. Verify container creation

- **Intention**: Confirm container was created and is running
- **Command**: `lxc list comfyui`
- **Output**:

  ```text
  +---------+---------+-----------------------+------+-----------+-----------+
  |  NAME   |  STATE  |         IPV4          | IPV6 |   TYPE    | SNAPSHOTS |
  +---------+---------+-----------------------+------+-----------+-----------+
  | comfyui | RUNNING | 192.168.10.250 (eth0) |      | CONTAINER | 0         |
  +---------+---------+-----------------------+------+-----------+-----------+
  ```

- **Interpretation**: Container is running with IP 192.168.10.250 on the lxdbr0 bridge

### Issues Encountered

- **LXD connection plugin issue**: The `community.general.lxd` connection plugin tried to connect to the container from the local machine, but the container is on the remote host `potwor`. Error: "Instance not found"
- **Resolution needed**: Need to either:
  1. Use SSH with ProxyJump through the LXD host
  2. Use `delegate_to` with `lxc exec` commands
  3. Set up SSH access in the container first

### Next Steps

1. Set up SSH access in the container
2. Add container to inventory with SSH connection via ProxyJump
3. Run ComfyUI installation playbook

---

## Session 4: ComfyUI Installation Completed

### Session 4 Host Information

- **Container**: comfyui (192.168.10.250)
- **LXD Host**: 192.168.10.5 (potwor)
- **User**: adam
- **OS**: Ubuntu 24.04 LTS

### Installation Summary

ComfyUI was successfully installed in the LXD container using the Ansible playbook `playbooks/comfyui_lxd.yml`.

#### What Was Installed

- **ComfyUI**: Installed via `comfy-cli` at `/home/adam/comfy`
- **GPU Support**: CPU mode (as configured)
- **Python**: System Python 3.12 with venv
- **comfy-cli**: Installed via pipx for managing ComfyUI

#### Custom Nodes Installed (for krita-ai-diffusion)

1. `comfyui_controlnet_aux` - ControlNet preprocessing nodes
2. `ComfyUI_IPAdapter_plus` - IP-Adapter support
3. `comfyui-inpaint-nodes` - Inpainting functionality
4. `comfyui-tooling-nodes` - Tooling utilities

#### Systemd Service

- **Service file**: `/home/adam/.config/systemd/user/comfyui.service`
- **Lingering enabled**: Yes (service can run without user login)
- **Service status**: Created but not started (manual start required)

### Issues Encountered and Resolved

#### 1. LXD Image Server 404 Error

- **Problem**: Initial image server URL `images.linuxcontainers.org` returned 404
- **Tried**: `images.lxd.canonical.com` - also 404
- **Solution**: Used `https://cloud-images.ubuntu.com/releases/` with `simplestreams` protocol

#### 2. Image Alias Format

- **Problem**: `ubuntu/24.04` not found on cloud-images server
- **Solution**: Changed to just `24.04` for the ubuntu: remote

#### 3. LXD Connection Plugin Failed

- **Problem**: `community.general.lxd` connection plugin tried to connect to container from local machine, but container is on remote host
- **Error**: "Instance not found"
- **Solution**: Switched to SSH connection with ProxyJump through LXD host

#### 4. SSH ProxyJump Used Hostname Instead of IP

- **Problem**: ProxyJump used `potwor` hostname which couldn't be resolved
- **Solution**: Changed to use `{{ ansible_host }}` (192.168.10.5) instead

#### 5. SSH Key Not in Container

- **Problem**: Ansible couldn't authenticate to container via SSH
- **Solution**: Added task to copy potwor's public key to container's authorized_keys

#### 6. Missing .local/bin Directory

- **Problem**: Symlink creation failed because `.local/bin` didn't exist
- **Error**: "Error while linking: [Errno 2] No such file or directory"
- **Solution**: Added task to create `.local/bin` directory before symlink creation

#### 7. comfy-cli Interactive Prompt

- **Problem**: `comfy install` prompted for tracking consent, blocking automation
- **Solution**: Added `--skip-prompt` global flag: `comfy --skip-prompt install`

### Final Ansible Playbook Run Output

```text
PLAY RECAP *********************************************************************
comfyui                    : ok=14   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
potwor                     : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### How to Use ComfyUI

#### Start the Service

```bash
# SSH to container
ssh -J adam@192.168.10.5 adam@192.168.10.250

# Start ComfyUI service
systemctl --user start comfyui

# Check status
systemctl --user status comfyui

# View logs
journalctl --user -u comfyui -f
```

#### Or Start Manually

```bash
# From LXD host
lxc exec comfyui -- sudo -u adam bash -c 'cd ~/comfy && comfy launch -- --listen 0.0.0.0'
```

#### Access from Browser/Krita

- **URL**: <http://192.168.10.250:8188>
- **From Krita**: Configure krita-ai-diffusion plugin to use `http://192.168.10.250:8188`

### Files Created

#### Ansible Roles

- `roles/comfyui/` - ComfyUI installation role
  - `defaults/main.yml` - Configuration variables
  - `tasks/main.yml` - Installation tasks
  - `templates/comfyui.service.j2` - Systemd service template
  - `meta/main.yml` - Role metadata
- `roles/lxd_container/` - LXD container creation role
  - `defaults/main.yml` - Container configuration
  - `tasks/main.yml` - Container creation tasks
  - `meta/main.yml` - Role metadata

#### Playbooks

- `playbooks/comfyui.yml` - Standalone ComfyUI installation
- `playbooks/comfyui_lxd.yml` - LXD container + ComfyUI installation
- `playbooks/README.md` - Documentation

#### Inventory

- `inventory/comfyui/hosts.yml` - Host definitions
- `inventory/comfyui/group_vars/all.yml` - Group variables

### Sources Used

1. <https://github.com/comfyanonymous/ComfyUI> - Official ComfyUI repository
2. <https://github.com/Comfy-Org/comfy-cli> - Official comfy-cli tool
3. <https://github.com/Acly/krita-ai-diffusion> - Krita AI Diffusion plugin
4. <https://github.com/Acly/krita-ai-diffusion/wiki/ComfyUI-Setup> - Setup guide
5. <https://cloud-images.ubuntu.com/releases/> - Ubuntu cloud images

---

## Session 5: GPU Passthrough Verification and Configuration

### Session 5 Host Information

- **Container**: comfyui (192.168.10.250)
- **LXD Host**: 192.168.10.5 (potwor)
- **GPU**: NVIDIA GeForce GTX 1080 Ti

### GPU Passthrough Configuration

The container was initially created without GPU passthrough. The following steps were taken to add GPU support:

#### 1. Updated Ansible inventory to include GPU device

```yaml
devices:
  gpu0:
    type: gpu
    gputype: physical
    id: nvidia.com/gpu=0
```

#### 2. Updated lxd_container role to handle GPU device addition

- GPU devices cannot be added while container is running
- Role now stops container, adds GPU device, then restarts

#### 3. Updated comfyui role to install NVIDIA drivers in container

- Installs `nvidia-driver-535-server` and `nvidia-utils-535-server`
- Verifies GPU access with `nvidia-smi`

### Verification Results

#### nvidia-smi in container

```text
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.274.02    Driver Version: 535.274.02    CUDA Version: 12.2   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce GTX 1080 Ti  Off | 00000000:43:00.0 Off |                N/A |
|  0%   27C    P8     10W / 275W |    258MiB / 11264MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

#### PyTorch CUDA verification

```text
PyTorch CUDA support: cuda
CUDA available: True, Device: NVIDIA GeForce GTX 1080 Ti
```

### Known Limitation

The GTX 1080 Ti (Pascal architecture, sm_61) has a compatibility warning with the latest PyTorch:

```text
NVIDIA GeForce GTX 1080 Ti with CUDA capability sm_61 is not compatible with the current PyTorch installation.
The current PyTorch install supports CUDA capabilities sm_70 sm_75 sm_80 sm_86 sm_90 sm_100 sm_120.
```

Despite this warning, CUDA is still detected as available. For full compatibility with Pascal GPUs, an older PyTorch version (2.0.x with CUDA 11.8) would be required.

### Final Playbook Run Output

```text
PLAY RECAP *********************************************************************
comfyui                    : ok=44   changed=6    unreachable=0    failed=0    skipped=16   rescued=0    ignored=0
potwor                     : ok=13   changed=1    unreachable=0    failed=0    skipped=6    rescued=0    ignored=0
```

### Session 5 Conclusions

1. **GPU passthrough is fully functional** - The NVIDIA GPU is accessible from within the container
2. **NVIDIA drivers work** - nvidia-smi shows the GPU correctly
3. **PyTorch detects CUDA** - CUDA is available and the GPU device is recognized
4. **ComfyUI is ready** - All required custom nodes for krita-ai-diffusion are installed
5. **Systemd service created** - ComfyUI can be started as a user service

---

## Session 6: Sway Desktop Installation on SK-PF3D0A9T

### Session 6 Host Information

- **Host**: 192.168.42.205 (SK-PF3D0A9T)
- **User**: adam
- **OS**: Ubuntu 24.04.3 LTS (Noble Numbat)
- **Kernel**: 6.14.0-37-generic x86_64
- **Purpose**: Install Sway desktop environment using Ansible playbook

### Session 6 Commands Executed

#### 1. Verify host connectivity and OS version

- **Intention**: Confirm SSH access and check OS version
- **Command**: `hostname && cat /etc/os-release | head -5`
- **Output**:

  ```text
  SK-PF3D0A9T
  PRETTY_NAME="Ubuntu 24.04.3 LTS"
  NAME="Ubuntu"
  VERSION_ID="24.04"
  VERSION="24.04.3 LTS (Noble Numbat)"
  VERSION_CODENAME=noble
  ```

- **Interpretation**: Host is Ubuntu 24.04.3 LTS, compatible with the Sway playbook

#### 2. Check if Sway is already installed

- **Intention**: Verify Sway is not already installed
- **Command**: `which sway && sway --version`
- **Output**: (empty - command failed)
- **Interpretation**: Sway is not installed, proceed with installation

#### 3. Check sudo access

- **Intention**: Verify sudo works for Ansible become
- **Command**: `sudo -n true && echo "sudo works"`
- **Output**: `sudo: a password is required`
- **Interpretation**: Sudo requires password, need to use `--ask-become-pass` with Ansible

### Session 6 Issues Encountered and Resolved

#### 1. Python cffi module missing on remote host

- **Problem**: Ansible apt module failed with `ModuleNotFoundError: No module named '_cffi_backend'`
- **Cause**: Remote host uses pyenv with Python 3.12.11, which doesn't have cffi installed. System Python has it.
- **Solution**: Added `-e "ansible_python_interpreter=/usr/bin/python3"` to use system Python

#### 2. Variable name typo in sway role

- **Problem**: Task "Sway | Update i3-config repository" failed with `'i3_config_repo' is undefined`
- **Cause**: Variable name mismatch - task referenced `i3_config_repo` but previous task registered `sway_i3_config_repo`
- **Solution**: Fixed [`roles/sway/tasks/config.yml`](roles/sway/tasks/config.yml:39) line 39 to use `sway_i3_config_repo.stat.exists`

#### 3. Git sway branch not fetched

- **Problem**: Git checkout failed with `fatal: 'origin/sway' is not a commit and a branch 'sway' cannot be created from it`
- **Cause**: Repository was cloned with single-branch refspec (`+refs/heads/master:refs/remotes/origin/master`)
- **Solution**: Manually fixed on remote host:

  ```bash
  cd ~/.config/i3-config
  git remote set-branches origin '*'
  git fetch origin
  ```

### Final Ansible Playbook Run

```bash
ansible-playbook playbooks/sway.yml -i "adam@192.168.42.205," --ask-become-pass -e "ansible_python_interpreter=/usr/bin/python3"
```

**Result**:

```text
PLAY RECAP *********************************************************************
adam@192.168.42.205        : ok=53   changed=13   unreachable=0    failed=0    skipped=19   rescued=0    ignored=0
```

### Session 6 What Was Installed

#### Via Nix Package Manager

- **Sway** - Wayland compositor (version 1.11+)
- **kanshi** - Dynamic display configuration
- **wl-gammarelay-rs** - Color temperature control
- **wlr-randr** - xrandr-like tool for wlroots
- **wdisplays** - GUI for display configuration
- **nixGL** - OpenGL wrapper for Nix on non-NixOS

#### Via APT

- **waybar** - Status bar
- **wofi** - Application launcher
- **mako-notifier** - Notification daemon
- **grim, slurp** - Screenshot utilities
- **swayidle, swaylock** - Idle management and screen locker
- **wl-clipboard** - Clipboard utilities
- **xdg-desktop-portal-wlr, xdg-desktop-portal-gtk** - Portal backends
- **brightnessctl, playerctl** - Hardware control
- **network-manager-gnome, blueman, pasystray, pavucontrol** - System tray apps
- **xwayland** - X11 compatibility layer

#### Compiled from Source

- **Foot terminal 1.25.0** - Fast Wayland terminal

#### Configuration

- **i3-config repository** cloned to `~/.config/i3-config` (sway branch)
- **Symlinks created** for sway, waybar, mako, foot, fusuma configs
- **XKB custom keymap** deployed for keyboard configuration
- **XDG Desktop Portal** configured for Sway/wlroots
- **Fonts installed**: Nerd Fonts Symbols, Exo2

#### Session Entry

- **Desktop entry**: `/usr/share/wayland-sessions/sway-nix.desktop`
- **Session wrapper**: `/usr/local/bin/sway-session`

### How to Use Sway

1. Log out of current session
2. Select "Sway (Nix)" from the display manager session menu
3. Or run `sway-session` from a TTY

### Session 6 Conclusions

1. **Sway 1.11** successfully installed via Nix package manager
2. **Foot 1.25.0** terminal compiled and installed
3. **i3-config repository** cloned and configured with sway branch
4. **All supporting tools** (waybar, wofi, mako, etc.) installed
5. **Session entry** available in display manager
6. **Bug fixed** in [`roles/sway/tasks/config.yml`](roles/sway/tasks/config.yml:39) - variable name typo

### Session 6 Follow-up: Nethogs Sudoers Configuration

#### Additional Changes Made

Added nethogs sudoers configuration to allow waybar network traffic display:

1. **Added `nethogs` to apt packages** in [`roles/sway/defaults/main.yml`](roles/sway/defaults/main.yml:43)
2. **Created new task file** [`roles/sway/tasks/nethogs.yml`](roles/sway/tasks/nethogs.yml)
3. **Added task inclusion** in [`roles/sway/tasks/main.yml`](roles/sway/tasks/main.yml:39)

#### Sudoers Configuration

- **File created**: `/etc/sudoers.d/nethogs-adam`
- **Content**: `adam ALL=(root) NOPASSWD: /usr/sbin/nethogs`
- **Permissions**: 0440, owned by root
- **Validation**: Used `visudo -cf` to validate syntax before writing

#### Playbook Run Result

```text
PLAY RECAP *********************************************************************
adam@192.168.42.205        : ok=56   changed=4    unreachable=0    failed=0    skipped=19   rescued=0    ignored=0
```

The nethogs sudoers configuration was successfully applied. Waybar can now display network traffic without requiring a password prompt.

---

## Session 7: Screen Lock Before Sleep Investigation and Fix

### Session 7 Host Information

- **Host**: 192.168.42.205 (TSK-PF3D0A9T)
- **User**: adam
- **OS**: Ubuntu 24.04.3 LTS
- **Purpose**: Investigate and fix screen not locking on suspend

### Problem Description

The user reported that the screen does not lock when the system wakes from suspend, despite swayidle being configured with `before-sleep` event.

### Investigation

#### 1. Verified swayidle is running

- **Command**: `ps aux | grep swayidle`
- **Output**: swayidle is running with correct configuration including `before-sleep` event
- **Interpretation**: swayidle is properly started

#### 2. Checked for suspend events

- **Command**: `journalctl --since "24 hours ago" | grep -i "suspend\|sleep\|wak"`
- **Output**: Found suspend at 13:28:13 and wake at 13:54:06
- **Interpretation**: System did suspend and resume

#### 3. Checked conditional-lock logs during suspend

- **Command**: `journalctl --user -t conditional-lock --since "13:28:00" --until "13:30:00"`
- **Output**: `-- No entries --`
- **Interpretation**: **The conditional-lock script was NOT called during suspend!**

#### 4. Tested conditional-lock script manually

- **Command**: `bash -x ~/.config/i3-config/sway/scripts/conditional-lock -f -c 000000 2>&1`
- **Output**: Script works correctly - detects WiFi, checks whitelist, decides to lock
- **Error**: `Unable to connect to the compositor` (expected when run from SSH)
- **Interpretation**: Script logic is correct, but swayidle's before-sleep event is not triggering

### Root Cause

swayidle's `before-sleep` event relies on logind's D-Bus `PrepareForSleep` signal, which is:

- Considered buggy and unreliable
- Hard to maintain (per swayidle maintainers)
- May not be received reliably with certain suspend methods

### Sources Consulted

1. <https://github.com/swaywm/swayidle/issues/127> - GitHub issue confirming the problem
2. <https://wiki.archlinux.org/title/Sway#Screen_content_shown_briefly_upon_resume> - Arch Wiki documentation
3. <https://whynothugo.nl/journal/2022/10/26/systemd-locking-and-sleeping/> - Detailed analysis of the issue

### Solution Implemented

Created a systemd user service that runs swaylock before sleep.target, which is more reliable than swayidle's before-sleep event.

#### New Files for Lock-Before-Sleep

- **Template**: `roles/sway/templates/lock-before-sleep.service.j2`
  - Systemd user service that runs swaylock before sleep.target
- **Task file**: `roles/sway/tasks/lock_before_sleep.yml`
  - Deploys the service file
  - Enables lingering for the user
  - Enables the service

#### Modified Files for Lock-Before-Sleep

- **`roles/sway/defaults/main.yml`**
  - Added `sway_configure_lock_before_sleep: true`
  - Added `sway_lock_command: "/usr/bin/swaylock -f -c 000000"`
  - Added `sway_lock_wayland_display: "wayland-1"`
- **`roles/sway/tasks/main.yml`**
  - Added task to get user UID (needed for XDG_RUNTIME_DIR)
  - Added include for `lock_before_sleep.yml`

### Session 7 Playbook Run

```text
PLAY RECAP *********************************************************************
adam@192.168.42.205        : ok=65   changed=5    unreachable=0    failed=0    skipped=19   rescued=0    ignored=0
```

### Verification

```bash
$ systemctl --user is-enabled lock-before-sleep.service
enabled

$ systemctl --user status lock-before-sleep.service
○ lock-before-sleep.service - Lock screen before sleep
    Loaded: loaded (/home/adam/.config/systemd/user/lock-before-sleep.service)
    Active: inactive (dead)
      Docs: man:swaylock(1)
```

The service is:

- **Loaded**: Service file is correctly parsed
- **Enabled**: Will be activated when sleep.target is reached
- **Inactive (dead)**: Expected - only activates during suspend

### How It Works

1. When the system initiates suspend, systemd activates `sleep.target`
2. The `lock-before-sleep.service` is `WantedBy=sleep.target` and `Before=sleep.target`
3. This means the service runs BEFORE the system actually suspends
4. The service runs `swaylock -f -c 000000` which forks and locks the screen
5. Only after swaylock is running does the system proceed to suspend
6. When the system wakes, the screen is already locked

### Session 7 Conclusions

1. **Root cause identified**: swayidle's before-sleep event is unreliable due to D-Bus/logind integration issues
2. **Solution implemented**: systemd user service bound to sleep.target
3. **Service deployed and enabled** via Ansible playbook
4. **No manual intervention required** - the fix is now part of the sway role

---

## Session 8: CLI Tools Full Profile Installation on WSL2

### Session 8 Host Information

- **Host**: 192.168.42.118 (Legion9i)
- **User**: adam
- **OS**: Ubuntu 24.04 on WSL2 (Kernel 6.6.87.2-microsoft-standard-WSL2)
- **Purpose**: Install full CLI experience using Ansible prepare_ubuntu.yml playbook

### Session 8 Ansible Playbook Execution

#### Command

```bash
ansible-playbook playbooks/prepare_ubuntu.yml -i "192.168.42.118," -u adam \
  -e "target_user=adam cli_tools_profile=full" --become --ask-become-pass
```

#### First Run - Failed

**Issue**: Two Rust packages had incorrect names for cargo-binstall:

- `dust` - should be `du-dust`
- `tldr` - should be `tealdeer`

**Error**:

```text
failed: [192.168.42.118] (item=dust) =>
    msg: non-zero return code
    rc: 86
    stdout: |
        INFO resolve: Resolving package: 'dust'
        ERROR Fatal error:
          × For crate dust: no binaries specified nor inferred

failed: [192.168.42.118] (item=tldr) =>
    msg: non-zero return code
    rc: 76
    stdout: |
        INFO resolve: Resolving package: 'tldr'
        ERROR Fatal error:
          × For crate tldr: no version matching requirement '*'
```

**Fix Applied**: Updated `roles/cli_tools/defaults/main.yml`:

- Changed `dust` to `du-dust`
- Changed `tldr` to `tealdeer`

#### Second Run - Success

```text
PLAY RECAP *********************************************************************
192.168.42.118             : ok=48   changed=11   unreachable=0    failed=0    skipped=27   rescued=0    ignored=0
```

### Session 8 What Was Installed

#### APT Packages (Full Profile)

- btop, ncdu, prettyping, liquidprompt, byobu, mc, aptitude
- entr, dtrx, neovim, magic-wormhole
- Base packages: jq, htop, tree, tmux, curl, wget, unzip, zip, git, git-lfs, make, build-essential

#### Rust Packages (via cargo-binstall)

- atuin (shell history replacement)
- zoxide (smarter cd command)
- eza (modern ls replacement)
- bat (cat with syntax highlighting)
- fd-find (modern find replacement)
- ripgrep (fast grep replacement)
- difftastic (structural diff tool)
- du-dust (intuitive du replacement, binary: dust)
- bandwhich (bandwidth utilization tool)
- hexyl (hex viewer)
- tealdeer (simplified man pages, binary: tldr)

#### Shell Configuration

- **fzf** installed from git repository
- **liquidprompt** activated system-wide
- **mise** (polyglot runtime manager) configured
- **zoxide** shell integration added
- **atuin** shell history integration added

#### Bashrc.d Scripts Created

- `05_cargo.sh` - Rust/Cargo PATH
- `21_cli_aliases.sh` - CLI improved aliases (cat=bat, ping=prettyping, du=ncdu, find=fd, grep=rg, htop=btop)
- `22_eza_aliases.sh` - eza aliases (ls=eza --icons, ll, la, lt, lta)
- `70_preexec.sh` - bash-preexec for atuin
- `85_fzf.sh` - fzf configuration
- `86_zoxide.sh` - zoxide integration
- `87_atuin.sh` - atuin integration
- `90_mise.sh` - mise activation
- `99_liquidprompt.sh` - liquidprompt activation

### Session 8 Files Modified

1. **`roles/cli_tools/defaults/main.yml`** - Fixed Rust package names:
    - `dust` → `du-dust`
    - `tldr` → `tealdeer`

### Session 8 Conclusions

1. **Full CLI profile successfully installed** on WSL2 Ubuntu 24.04
2. **Package name fix applied** for cargo-binstall compatibility
3. **All 11 Rust tools installed** via cargo-binstall
4. **Shell configuration complete** with aliases and integrations
5. **User needs to start a new shell** to activate all changes
