# Fingerprint Authentication Configuration for ThinkPad Notebooks

**Document for Ansible Instrumentation Team**  
**Date:** 2026-01-21  
**Target OS:** Ubuntu 24.04 LTS  
**Target Hardware:** Lenovo ThinkPad laptops with Synaptics fingerprint readers

## Overview

This document describes the configuration changes required to enable fingerprint authentication for:

1. **sudo** - Command-line privilege escalation
2. **swaylock** - Screen locker for Sway/Wayland (requires custom build)

## Hardware Requirements

### Supported Fingerprint Readers

| USB ID | Device Name | Driver |
|--------|-------------|--------|
| 06cb:00bd | Synaptics Prometheus MIS Touch | Synaptics Sensors (libfprint) |
| 06cb:009a | Synaptics Metallica MIS Touch | python-validity (separate driver) |
| 06cb:00c2 | Synaptics Sensors | Synaptics Sensors (libfprint) |

**Note:** Device 06cb:00bd is natively supported by libfprint. Device 06cb:009a requires the python-validity driver from a PPA.

## Required Packages

### APT Packages (Pre-installed on Ubuntu 24.04)

```yaml
packages:
  - fprintd                    # 1.94.3-1
  - libfprint-2-2              # 1:1.94.7+tod1-0ubuntu5~24.04.4
  - libfprint-2-tod1           # 1:1.94.7+tod1-0ubuntu5~24.04.4
  - libpam-fprintd             # 1.94.3-1
```

### Build Dependencies for swaylock-fprintd

```yaml
build_packages:
  - meson
  - ninja-build
  - libwayland-dev
  - wayland-protocols
  - libxkbcommon-dev
  - libcairo2-dev
  - libgdk-pixbuf-2.0-dev
  - libpam0g-dev
  - libdbus-1-dev
  - libglib2.0-dev
  - scdoc
  - git
```

## Configuration Changes

### 1. PAM Configuration: /etc/pam.d/common-auth

**Method:** Use `pam-auth-update` to enable fingerprint authentication.

**Ansible Task:**

```yaml
- name: Enable fingerprint authentication in PAM
  ansible.builtin.debconf:
    name: libpam-fprintd
    question: libpam-fprintd/enable-fingerprint
    value: 'true'
    vtype: boolean
  notify: Run pam-auth-update

- name: Run pam-auth-update
  ansible.builtin.command: pam-auth-update --enable fprintd
  changed_when: true
```

**Resulting /etc/pam.d/common-auth:**

```text
# here are the per-package modules (the "Primary" block)
auth    [success=3 default=ignore]  pam_fprintd.so max-tries=1 timeout=10 # debug
auth    [success=2 default=ignore]  pam_unix.so nullok try_first_pass
auth    [success=1 default=ignore]  pam_sss.so use_first_pass
# here's the fallback if no module succeeds
auth    requisite           pam_deny.so
auth    required            pam_permit.so
auth    optional            pam_cap.so
```

### 2. PAM Configuration: /etc/pam.d/swaylock

**Note:** Standard swaylock has race condition issues with fingerprint authentication. The solution is to use swaylock-fprintd which handles fingerprint natively via D-Bus.

**Final configuration (for use with swaylock-fprintd):**

```text
#
# PAM configuration file for the swaylock screen locker. By default, it includes
# the 'login' configuration file (see /etc/pam.d/login)
#

auth include login
```

swaylock-fprintd handles fingerprint authentication directly via the fprintd D-Bus service, so no special PAM configuration is needed.

### 3. User Group Membership

Users must be in the `input` group to access the fingerprint reader:

```yaml
- name: Add user to input group for fingerprint access
  ansible.builtin.user:
    name: "{{ ansible_user }}"
    groups: input
    append: yes
```

### 4. swaylock-fprintd Installation

Standard swaylock does not properly support fingerprint authentication. Use the swaylock-fprintd fork:

**Repository:** <https://github.com/SL-RU/swaylock-fprintd>

**Ansible Tasks:**

```yaml
- name: Clone swaylock-fprintd
  ansible.builtin.git:
    repo: https://github.com/SL-RU/swaylock-fprintd.git
    dest: /opt/swaylock-fprintd
    version: fprintd
    depth: 1

- name: Configure swaylock-fprintd build
  ansible.builtin.command:
    cmd: meson build
    chdir: /opt/swaylock-fprintd
    creates: /opt/swaylock-fprintd/build/build.ninja

- name: Build swaylock-fprintd
  ansible.builtin.command:
    cmd: ninja -C build
    chdir: /opt/swaylock-fprintd
    creates: /opt/swaylock-fprintd/build/swaylock

- name: Install swaylock-fprintd
  ansible.builtin.command:
    cmd: ninja -C build install
    chdir: /opt/swaylock-fprintd
  become: yes
```

**Installation Path:** `/usr/local/bin/swaylock` (takes precedence over `/usr/bin/swaylock`)

### 5. swaylock Configuration File

**Important:** swaylock-fprintd requires the `-p` or `--fingerprint` flag to enable fingerprint scanning. To enable it by default, create a configuration file.

**Configuration File:** `~/.config/swaylock/config`

**Ansible Tasks:**

```yaml
- name: Create swaylock config directory
  ansible.builtin.file:
    path: "{{ ansible_env.HOME }}/.config/swaylock"
    state: directory
    mode: '0755'

- name: Create swaylock config with fingerprint enabled
  ansible.builtin.copy:
    dest: "{{ ansible_env.HOME }}/.config/swaylock/config"
    content: |
      # swaylock configuration
      # Enable fingerprint authentication (requires swaylock-fprintd)
      fingerprint
    mode: '0644'
```

**Alternative:** Run swaylock with `-p` flag: `swaylock -p`

### 6. USB Reset Wrapper for Synaptics Fingerprint Readers

**Problem:** Synaptics fingerprint readers (06cb:00bd) can get into a stalled state where fprintd reports "endpoint stalled or request not supported" and the device becomes unavailable. This commonly happens after suspend/resume cycles or prolonged use.

**Solution:** Create a wrapper script that resets the USB device before launching swaylock.

#### 6.1 Reset Script: /usr/local/bin/reset-fingerprint-reader

```bash
#!/bin/bash
# Reset the Synaptics fingerprint reader
# USB ID: 06cb:00bd (Prometheus MIS Touch Fingerprint Reader)
exec /usr/bin/usbreset "06cb:00bd"
```

**Ansible Task:**

```yaml
- name: Install fingerprint reader reset script
  ansible.builtin.copy:
    dest: /usr/local/bin/reset-fingerprint-reader
    mode: '0755'
    content: |
      #!/bin/bash
      # Reset the Synaptics fingerprint reader
      # USB ID: 06cb:00bd (Prometheus MIS Touch Fingerprint Reader)
      exec /usr/bin/usbreset "06cb:00bd"
```

#### 6.2 Sudoers Configuration: /etc/sudoers.d/fingerprint-reset

Allow passwordless execution of the reset script:

```text
# Allow user to reset the fingerprint reader without password
adam ALL=(ALL) NOPASSWD: /usr/local/bin/reset-fingerprint-reader
```

**Ansible Task:**

```yaml
- name: Configure passwordless sudo for fingerprint reset
  ansible.builtin.copy:
    dest: /etc/sudoers.d/fingerprint-reset
    mode: '0440'
    validate: 'visudo -cf %s'
    content: |
      # Allow {{ ansible_user }} to reset the fingerprint reader without password
      {{ ansible_user }} ALL=(ALL) NOPASSWD: /usr/local/bin/reset-fingerprint-reader
```

#### 6.3 Swaylock Wrapper: /usr/local/bin/swaylock-wrapper

```bash
#!/bin/bash
# swaylock-wrapper - Wrapper script for swaylock-fprintd
# Resets the Synaptics fingerprint reader before launching swaylock
# to prevent "endpoint stalled" errors.

# Reset the fingerprint reader (requires passwordless sudo configured)
sudo /usr/local/bin/reset-fingerprint-reader >/dev/null 2>&1

# Small delay to allow the device to reinitialize
sleep 0.5

# Execute the real swaylock binary with all passed arguments
exec /usr/local/bin/swaylock-fprintd-bin "$@"
```

**Ansible Tasks:**

```yaml
- name: Rename swaylock-fprintd binary
  ansible.builtin.command:
    cmd: mv /usr/local/bin/swaylock /usr/local/bin/swaylock-fprintd-bin
    creates: /usr/local/bin/swaylock-fprintd-bin

- name: Install swaylock wrapper script
  ansible.builtin.copy:
    dest: /usr/local/bin/swaylock-wrapper
    mode: '0755'
    content: |
      #!/bin/bash
      sudo /usr/local/bin/reset-fingerprint-reader >/dev/null 2>&1
      sleep 0.5
      exec /usr/local/bin/swaylock-fprintd-bin "$@"

- name: Create swaylock symlink to wrapper
  ansible.builtin.file:
    src: /usr/local/bin/swaylock-wrapper
    dest: /usr/local/bin/swaylock
    state: link
```

#### 6.4 Required Package

```yaml
packages:
  - usbutils  # Provides usbreset command
```

## Fingerprint Enrollment

Fingerprint enrollment must be done per-user and cannot be automated via Ansible.

**Manual enrollment command:**

```bash
sudo fprintd-enroll <username>
```

**Important:** Running `sudo fprintd-enroll` without a username enrolls for root, not the current user.

**Verification:**

```bash
fprintd-list <username>
fprintd-verify
```

## Security Considerations

### CVE-2024-37408

Using fingerprint-only authentication for sudo/polkit is a security risk as background processes can hijack fingerprint authentication. The default configuration uses fingerprint as an **alternative** to password, not a replacement.

### Recommended Security Settings

The PAM configuration uses:

- `max-tries=1` - Only one fingerprint attempt before falling back
- `timeout=10` - 10-second timeout for fingerprint scan

## Verification Commands

```bash
# Check fingerprint reader detection
lsusb | grep -i finger

# Check fprintd service
systemctl status fprintd.service

# Check firmware status
fwupdmgr get-devices | grep -A 20 Prometheus

# List enrolled fingerprints
fprintd-list <username>

# Test fingerprint verification
fprintd-verify

# Test sudo with fingerprint
sudo -k && sudo whoami
```

## Rollback Procedure

To disable fingerprint authentication:

```bash
sudo pam-auth-update --remove fprintd
```

To restore original swaylock:

```bash
sudo rm /usr/local/bin/swaylock
# System will fall back to /usr/bin/swaylock
```

## File Checksums (for verification)

After configuration, verify these files:

| File | Expected State |
|------|----------------|
| `/etc/pam.d/common-auth` | Contains `pam_fprintd.so` line |
| `/etc/pam.d/swaylock` | Contains `auth include login` |
| `/usr/local/bin/swaylock` | swaylock-fprintd binary |
| `/var/lib/fprint/<username>/` | Enrolled fingerprint data |

## Troubleshooting

### "No devices available"

- Check USB connection: `lsusb | grep -i finger`
- Restart fprintd: `systemctl restart fprintd.service`
- Check firmware: `fwupdmgr get-devices`

### "enroll-duplicate"

- Fingerprint already enrolled for another user
- Delete existing enrollment: `sudo fprintd-delete <username>`

### swaylock fingerprint not working

- Ensure swaylock-fprintd is installed (not standard swaylock)
- Check: `which swaylock` should show `/usr/local/bin/swaylock`
