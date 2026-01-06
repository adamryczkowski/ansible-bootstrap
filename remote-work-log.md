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
