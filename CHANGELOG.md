# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- SDTD Server role: Complete "7 Days to Die" dedicated game server installation and configuration for Ubuntu 24.04 LTS in LXC containers
- SDTD Server role: LinuxGSM-based installation for simplified server management (start, stop, restart, update, backup, console)
- SDTD Server role: Comprehensive serverconfig.xml configuration via community.general.xml module
- SDTD Server role: Systemd service integration with automatic startup on boot
- SDTD Server role: UFW firewall configuration for game ports (26900-26905 TCP/UDP)
- SDTD Server role: Dedicated user account creation for security best practices
- SDTD Server role: Configurable game settings (world type, difficulty, max players, EAC, control panel, telnet)
- Playbooks: `sdtd_server.yml` for deploying 7 Days to Die server with pre-flight checks (Ubuntu, memory, disk)
- Playbooks: `sdtd_server_lxd.yml` for complete LXD-based deployment (container creation, cli-improved, game server, port forwarding)
- Inventory: `sdtd_server` inventory for LXD-based 7D2D server deployment on 192.168.42.5
- Molecule: `sdtd-server` scenario for LXD-based testing of server role
- Sway role: Full Arch Linux support - native pacman installation with 32 packages including sway, waybar, wofi, mako, foot, and all ecosystem tools
- Sway role: Arch Linux support for fonts.yml - added pacman package installation with equivalent font packages (noto-fonts, noto-fonts-emoji, otf-font-awesome, ttf-fira-code)
- Sway role: Added unzip, python-psutil, and dconf to Arch Linux packages for font extraction and GTK theme configuration
- ZSwap role: Configure ZSwap compressed swap cache for improved system performance on Ubuntu 24.04 LTS
- ZSwap role: Configurable compressor (zstd, lz4, lzo, etc.), zpool (zsmalloc, z3fold, zbud), and pool size
- ZSwap role: Automatic GRUB configuration with kernel boot parameters
- ZSwap role: Initramfs module configuration for compression algorithms
- ZSwap role: Verification tasks to confirm ZSwap configuration after applying
- Playbooks: `zswap.yml` for deploying ZSwap configuration to Ubuntu systems
- Justfile: `playbooks` action to list all playbooks with their descriptions
- Justfile: `select-playbook` action for interactive fzf-based playbook selection with preview, local/remote execution, sudo password prompts, dry-run mode, and Python interpreter detection
- Scripts: `select-playbook.sh` option to run against manually specified remote hosts with SSH parameter collection and optional inventory addition
- Scripts: `select-playbook.sh` tree-view host selection - shows all inventories with their hosts in a unified tree, select inventory (all hosts) or specific host
- Scripts: `scripts/list-playbooks.sh` helper for extracting playbook descriptions
- Scripts: `scripts/select-playbook.sh` interactive playbook selector with full workflow support and automatic detection of working Python interpreters for local execution
- CLI tools role: Profile-based CLI experience with `minimal` and `full` settings
- CLI tools role: `full` profile equivalent to puppet-bootstrap `--cli-improved` flag
- CLI tools role: Nerd Fonts installation (FiraCode) for terminal icons
- CLI tools role: Enhanced shell aliases (cat=bat, ls=eza, find=fd, grep=rg, etc.)
- CLI tools role: eza aliases with icons and git integration
- Playbooks: Updated prepare_ubuntu.yml and lxd_node.yml with cli_tools_profile support
- Sway role: PCManFM file manager with automatic dark/light theme switching via gsettings
- Sway role: GTK theme configuration task (gtk_theme.yml) for dconf-based theme management
- Documentation: GTK theme switching guide (docs/gtk-theme-switching.md)
- Sway role: iotop configuration for disk traffic monitoring in waybar (installs iotop-c with capabilities)
- Sway role: usbmon configuration for USB traffic monitoring in waybar (kernel module, udev rules, sudoers)
- Sway role: Slack Wayland compatibility fix (desktop entry override with GPU/EGL workaround flags)
- Sway role: Enable Wayland in GDM configuration (fixes Sway not appearing in session list)
- Sway role: TryExec directive in desktop entry for proper display manager detection
- Sway role: bright CLI tool for extended monitor brightness control (via pipx from GitHub)
- ComfyUI role for installing and configuring ComfyUI backend for krita-ai-diffusion
- LXD container role for creating and managing LXD containers with GPU passthrough
- Sway role for installing Sway window manager via Nix with nixGL support
- Sway role: nethogs sudoers configuration for waybar network traffic display
- ComfyUI playbooks: standalone (comfyui.yml) and LXD-based (comfyui_lxd.yml)
- ComfyUI inventory for deployment configuration
- Playbooks README.md with comprehensive documentation
- Troubleshooting section in README.md
- LXD E2E testing documentation in README.md
- CONTRIBUTING.md with development guidelines
- CHANGELOG.md following Keep a Changelog format
- Missing meta files for bashrc, common, rust, and user_setup roles
- Comprehensive header documentation to complex task files
- New justfile recipes: `format`, `security-scan`, `docs`, `clean`

### Changed

- Standardized username variable usage across all roles to use
  `{{ target_user | default(ansible_user) | default('adam') }}` pattern
- Updated Nerd Fonts version to v3.3.0 (configurable via variable)
- Improved error handling in rust role for cargo-binstall installation

### Fixed

- SDTD Server role: Fixed INJECT_FACTS_AS_VARS deprecation warnings (use `ansible_facts['fact_name']` syntax for Ansible 2.24+ compatibility)
- SDTD Server role: Added `acl` package to prerequisites for `become_user` support (GitHub issue ansible/ansible#74830)
- SDTD Server role: Added `python3-lxml` package for community.general.xml module (serverconfig.xml editing)
- SDTD Server role: Fixed user creation logic (removed faulty getent check, user module is idempotent)
- Rust role: Fixed INJECT_FACTS_AS_VARS deprecation warning (`ansible_env.PATH` → `ansible_facts['env']['PATH']`)
- Sway role: Fixed brightness key bindings not working for non-adam users (hardcoded /home/adam/ paths in i3-config repository are now replaced with the actual user's home directory via `sway_fix_hardcoded_paths` variable)
- Sway playbook: Added robust handling for broken third-party apt repositories (block/rescue pattern with automatic detection and disabling of problematic repos)
- CLI tools role: Fixed Rust package names for cargo-binstall (`dust` → `du-dust`, `tldr` → `tealdeer`)
- Sway playbook: Added python3-cffi pre-task for hosts with pyenv (fixes cryptography module import)
- Sway role: iotop task now resolves symlinks before setting capabilities (fixes "Not a regular file" error)
- Sway role: lock-before-sleep service now works correctly (changed from user service to system service, since sleep.target is system-level only; removed StopWhenUnneeded=yes to prevent swaylock from being killed on resume)
- Removed deprecated `parseable` option from .ansible-lint configuration
- Pre-commit configuration file patterns (removed incorrect path prefix)
- ansible-lint hook now uses local installation to avoid version conflicts
- Variable naming convention: renamed `authorized_operators` to
  `user_setup_authorized_operators`
- Molecule verification path in lxd-e2e scenario
- LXD preseed template syntax for storage pool configuration
- Rust role error handling for already-installed packages
- Sway role: variable name typo in config.yml (`i3_config_repo` → `sway_i3_config_repo`)
- Sway role: git update task now fetches all remote branches before checkout (fixes branch not found error when switching branches)
- Sway role: changed default config branch from `main` to `master` (correct branch name in i3-config repository)
- Sway role: fixed symlink creation to properly detect and remove existing directories (replaced broken lookup-based condition with stat module)
- Sway role: fixed XKB symlink creation logic to check source existence and remove existing directories before creating symlinks

## [0.1.0] - 2025-12-25

### Initial Release

- Initial Ansible-based system configuration
- Core roles: common, packages, user_setup, bashrc
- Desktop roles: desktop, i3wm, kitty, firefox, thunderbird
- Application roles: rust, cli_tools, r_node, lxd
- Molecule testing with Docker
- LXD E2E testing scenario
- Pre-commit hooks for code quality
- justfile for task automation
- Inventory structure for production, staging, and lxd-test

### Migration

- Replaced legacy bash puppet-bootstrap scripts with Ansible roles
- Migrated prepare_ubuntu.sh to prepare_ubuntu.yml playbook
- Migrated prepare_ubuntu_user.sh to prepare_user.yml playbook
- Migrated desktop-prepare.sh to desktop.yml playbook
- Migrated prepare_R-node.sh to r_node.yml playbook
- Migrated make-lxd-node.sh to lxd_node.yml playbook

[Unreleased]: https://github.com/yourusername/ansible-bootstrap/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/ansible-bootstrap/releases/tag/v0.1.0
