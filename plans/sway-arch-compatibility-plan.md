# Sway Playbook Arch Linux Compatibility Plan

## Overview

This plan adapts the existing Sway playbook (tested on Ubuntu 24.04) to also support Arch Linux. The key insight is that Arch Linux has recent Sway versions in its repositories, eliminating the need for Nix.

## Architecture Decision

Use Ansible's `ansible_os_family` and `ansible_distribution` facts to conditionally execute distro-specific tasks:

- `ansible_os_family == "Debian"` → Ubuntu/Debian
- `ansible_os_family == "Archlinux"` → Arch Linux

## Files to Modify

### 1. `playbooks/sway.yml`

**Changes:**

- Replace Ubuntu-specific pre_tasks with distro-agnostic approach
- Use `ansible.builtin.package` where possible
- Add conditional blocks for apt vs pacman

```yaml
pre_tasks:
  - name: Update package cache (Debian/Ubuntu)
    ansible.builtin.apt:
      update_cache: true
      cache_valid_time: 3600
    when: ansible_os_family == "Debian"

  - name: Update package cache (Arch)
    community.general.pacman:
      update_cache: true
    when: ansible_os_family == "Archlinux"

  - name: Install essential packages
    ansible.builtin.package:
      name: "{{ essential_packages[ansible_os_family] }}"
      state: present
```

### 2. `roles/sway/defaults/main.yml`

**Add Arch-specific package lists:**

```yaml
# Installation method: 'nix' for Ubuntu (latest version), 'native' for Arch
sway_install_method: "{{ 'native' if ansible_os_family == 'Archlinux' else 'nix' }}"

# Arch Linux packages (native Sway from repos)
sway_arch_packages:
  - sway
  - foot
  - waybar
  - wofi
  - mako
  - grim
  - slurp
  - swayidle
  - swaylock
  - wl-clipboard
  - swaybg
  - xdg-desktop-portal-wlr
  - xdg-desktop-portal-gtk
  - libnotify
  - brightnessctl
  - playerctl
  - network-manager-applet
  - blueman
  - pasystray
  - pavucontrol
  - xorg-xwayland
  - nethogs
  - pcmanfm
  - kanshi
  - wlr-randr
  - wdisplays

# Fusuma dependencies per distro
sway_fusuma_packages_debian:
  - ruby
  - ruby-dev
  - libevdev-dev
  - build-essential

sway_fusuma_packages_arch:
  - ruby
  - libevdev
  - base-devel

# Foot build dependencies per distro
sway_foot_build_deps_debian:
  - meson
  - ninja-build
  - pkg-config
  - scdoc
  - wayland-protocols
  - libwayland-dev
  - libpixman-1-dev
  - libfontconfig-dev
  - libfreetype-dev
  - libxkbcommon-dev
  - libutf8proc-dev
  - libfcft-dev
  - libnotify-dev
  - libtllist-dev
  - check
  - libsystemd-dev

sway_foot_build_deps_arch:
  - meson
  - ninja
  - pkgconf
  - scdoc
  - wayland-protocols
  - wayland
  - pixman
  - fontconfig
  - freetype2
  - libxkbcommon
  - utf8proc
  - fcft
  - libnotify
  - tllist
  - check
  - systemd-libs
```

### 3. `roles/sway/tasks/main.yml`

**Changes:**

- Add conditional for Nix vs native installation
- Skip foot source build on Arch (available in repos)

```yaml
- name: Sway | Include package installation (Debian/Ubuntu)
  ansible.builtin.include_tasks: apt_packages.yml
  when: ansible_os_family == "Debian"

- name: Sway | Include package installation (Arch)
  ansible.builtin.include_tasks: pacman_packages.yml
  when: ansible_os_family == "Archlinux"

- name: Sway | Include Nix installation
  ansible.builtin.include_tasks: nix.yml
  when: sway_install_method == 'nix' and ansible_os_family == "Debian"

- name: Sway | Include Foot terminal installation (from source)
  ansible.builtin.include_tasks: foot.yml
  when: sway_install_foot_from_source | bool and ansible_os_family == "Debian"
```

### 4. NEW: `roles/sway/tasks/pacman_packages.yml`

**Create new file for Arch package installation:**

```yaml
---
# Sway role - Install packages for Sway ecosystem on Arch Linux

- name: Sway | Install Sway and ecosystem packages from pacman
  community.general.pacman:
    name: "{{ sway_arch_packages }}"
    state: present
  become: true

- name: Sway | Ensure Pictures/Screenshots directory exists
  ansible.builtin.file:
    path: "/home/{{ sway_username }}/Pictures/Screenshots"
    state: directory
    mode: "0755"
    owner: "{{ sway_username }}"
    group: "{{ sway_username }}"
  become: true
```

### 5. `roles/sway/tasks/foot.yml`

**Changes:**

- Add distro-specific build dependencies
- Skip entirely on Arch (foot is in repos)

```yaml
- name: Sway | Install Foot build dependencies (Debian)
  ansible.builtin.apt:
    name: "{{ sway_foot_build_deps_debian }}"
    state: present
  when: ansible_os_family == "Debian"

- name: Sway | Install Foot build dependencies (Arch)
  community.general.pacman:
    name: "{{ sway_foot_build_deps_arch }}"
    state: present
  when: ansible_os_family == "Archlinux"
```

### 6. `roles/sway/tasks/fusuma.yml`

**Changes:**

- Use distro-specific package lists
- Replace apt with package module where possible

```yaml
- name: Sway | Install Fusuma dependencies (Debian)
  ansible.builtin.apt:
    name: "{{ sway_fusuma_packages_debian }}"
    state: present
  when: ansible_os_family == "Debian"

- name: Sway | Install Fusuma dependencies (Arch)
  community.general.pacman:
    name: "{{ sway_fusuma_packages_arch }}"
    state: present
  when: ansible_os_family == "Archlinux"

# Remove libinput-gestures only on Debian (not in Arch repos)
- name: Sway | Ensure libinput-gestures is not conflicting
  ansible.builtin.apt:
    name: libinput-gestures
    state: absent
  become: true
  when: ansible_os_family == "Debian"
```

### 7. `roles/sway/tasks/portal.yml`

**Changes:**

- Add pacman support

```yaml
- name: Install XDG Desktop Portal packages (Debian)
  ansible.builtin.apt:
    name:
      - xdg-desktop-portal
      - xdg-desktop-portal-gtk
      - xdg-desktop-portal-wlr
    state: present
  when: ansible_os_family == "Debian"

- name: Install XDG Desktop Portal packages (Arch)
  community.general.pacman:
    name:
      - xdg-desktop-portal
      - xdg-desktop-portal-gtk
      - xdg-desktop-portal-wlr
    state: present
  when: ansible_os_family == "Archlinux"
```

### 8. `roles/sway/tasks/bright.yml`

**Changes:**

- Add pacman support for pipx

```yaml
- name: Sway | Ensure pipx is installed (Debian)
  ansible.builtin.apt:
    name: pipx
    state: present
  when: ansible_os_family == "Debian"

- name: Sway | Ensure pipx is installed (Arch)
  community.general.pacman:
    name: python-pipx
    state: present
  when: ansible_os_family == "Archlinux"
```

### 9. `roles/sway/tasks/nethogs.yml`

**Changes:**

- Add pacman support

```yaml
- name: Sway | Install nethogs package (Debian)
  ansible.builtin.apt:
    name: nethogs
    state: present
  when: ansible_os_family == "Debian"

- name: Sway | Install nethogs package (Arch)
  community.general.pacman:
    name: nethogs
    state: present
  when: ansible_os_family == "Archlinux"
```

### 10. `roles/sway/tasks/iotop.yml`

**Changes:**

- Use `iotop` on Arch (not `iotop-c`)

```yaml
- name: Sway | Install iotop package (Debian)
  ansible.builtin.apt:
    name: iotop-c
    state: present
  when: ansible_os_family == "Debian"

- name: Sway | Install iotop package (Arch)
  community.general.pacman:
    name: iotop
    state: present
  when: ansible_os_family == "Archlinux"
```

### 11. `roles/sway/tasks/session.yml`

**Changes:**

- Make GDM configuration conditional
- Support SDDM and other display managers

```yaml
- name: Sway | Enable Wayland in GDM configuration
  ansible.builtin.lineinfile:
    path: /etc/gdm3/custom.conf
    regexp: '^#?WaylandEnable='
    line: 'WaylandEnable=true'
    insertafter: '^\[daemon\]'
    state: present
  become: true
  when:
    - sway_enable_wayland_in_gdm | default(true) | bool
    - ansible_os_family == "Debian"

- name: Sway | Enable Wayland in GDM configuration (Arch path)
  ansible.builtin.lineinfile:
    path: /etc/gdm/custom.conf
    regexp: '^#?WaylandEnable='
    line: 'WaylandEnable=true'
    insertafter: '^\[daemon\]'
    state: present
  become: true
  failed_when: false  # GDM may not be installed
  when:
    - sway_enable_wayland_in_gdm | default(true) | bool
    - ansible_os_family == "Archlinux"
```

### 12. `roles/sway/templates/sway.desktop.j2`

**Changes:**

- Conditional Exec path based on install method

```ini
[Desktop Entry]
Name=Sway{% if sway_install_method == 'nix' %} (Nix){% endif %}

Type=Application
{% if sway_install_method == 'nix' %}
Exec=/usr/local/bin/sway-session
{% else %}
Exec=sway
{% endif %}
```

## Implementation Order

1. **Phase 1: Core Package Management**
    - [x] Create `roles/sway/tasks/pacman_packages.yml`
    - [x] Update `roles/sway/defaults/main.yml` with Arch packages
    - [x] Modify `roles/sway/tasks/main.yml` for conditional includes

2. **Phase 2: Playbook Adaptation**
    - [x] Update `playbooks/sway.yml` pre_tasks
    - [x] Add distro detection and conditional logic

3. **Phase 3: Individual Task Files**
    - [x] Update `apt_packages.yml` with Debian condition
    - [x] Update `foot.yml` (skip on Arch)
    - [x] Update `fusuma.yml`
    - [x] Update `portal.yml`
    - [x] Update `bright.yml`
    - [x] Update `nethogs.yml`
    - [x] Update `iotop.yml`
    - [x] Update `session.yml`
    - [x] Update `fonts.yml` with Arch Linux pacman support (noto-fonts, noto-fonts-emoji, otf-font-awesome, ttf-fira-code)

4. **Phase 4: Templates**
    - [x] Update `sway.desktop.j2` (already has conditional for nix vs native)
    - [x] Update `sway-wrapper.sh.j2` (only used for Nix, Arch uses native sway)

5. **Phase 5: Testing**
    - [ ] Install Arch Linux in VM
    - [ ] Add VM to inventory
    - [ ] Run playbook on Arch VM
    - [ ] Verify Sway starts correctly
    - [ ] Test all components (waybar, wofi, etc.)

## Notes

- Arch Linux uses `/etc/gdm/custom.conf` instead of `/etc/gdm3/custom.conf`
- Arch may use SDDM instead of GDM - the desktop entry should work with both
- On Arch, Sway is installed natively, no nixGL wrapper needed
- Foot terminal is available in Arch repos, no need to build from source
- The `community.general.pacman` module requires `community.general` collection
