# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Sway role: Slack Wayland compatibility fix (desktop entry override with GPU/EGL workaround flags)
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

- Removed deprecated `parseable` option from .ansible-lint configuration
- Pre-commit configuration file patterns (removed incorrect path prefix)
- ansible-lint hook now uses local installation to avoid version conflicts
- Variable naming convention: renamed `authorized_operators` to
  `user_setup_authorized_operators`
- Molecule verification path in lxd-e2e scenario
- LXD preseed template syntax for storage pool configuration
- Rust role error handling for already-installed packages
- Sway role: variable name typo in config.yml (`i3_config_repo` → `sway_i3_config_repo`)

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
