# Ansible Bootstrap

Modern Ansible-based system configuration for Ubuntu workstations and servers.
Replaces legacy bash puppet-bootstrap scripts with idempotent, testable roles.

## Quick Start

```bash
# Bootstrap development environment
just bootstrap

# Run validation (pre-commit hooks)
just validate

# Run tests
just test
```

## Requirements

- Python 3.10+
- Ansible 2.14+ (via pipx)
- Docker (for Molecule testing)
- just (task runner)

## Installation

```bash
cd ansible-bootstrap
just bootstrap
```

This installs Ansible, Galaxy collections, Python deps, and pre-commit hooks.

## Project Structure

```text
ansible-bootstrap/
├── ansible.cfg           # Ansible configuration
├── justfile              # Task runner commands
├── requirements.yml      # Galaxy collections
├── requirements.txt      # Python dependencies
├── .pre-commit-config.yaml
├── inventory/
│   ├── production/       # Production hosts
│   ├── staging/          # Staging hosts
│   └── lxd.yml           # LXD dynamic inventory
├── playbooks/
│   ├── site.yml          # Main orchestration
│   ├── prepare_ubuntu.yml
│   ├── prepare_user.yml
│   ├── desktop.yml
│   ├── r_node.yml
│   └── lxd_node.yml
├── roles/
│   ├── common/           # Base system config
│   ├── packages/         # APT management
│   ├── user_setup/       # User creation
│   ├── bashrc/           # Shell config
│   ├── rust/             # Rust toolchain
│   ├── cli_tools/        # CLI tools
│   ├── desktop/          # Desktop environment
│   ├── i3wm/             # i3 window manager
│   ├── kitty/            # Kitty terminal
│   ├── firefox/          # Firefox browser
│   ├── thunderbird/      # Thunderbird email
│   ├── r_node/           # R and RStudio
│   └── lxd/              # LXD containers
└── molecule/
    └── default/          # Test scenario
```

## Playbooks

| Playbook             | Description                |
| -------------------- | -------------------------- |
| `site.yml`           | Full system configuration  |
| `prepare_ubuntu.yml` | Base Ubuntu setup          |
| `prepare_user.yml`   | User environment           |
| `desktop.yml`        | Desktop environment        |
| `r_node.yml`         | R development              |
| `lxd_node.yml`       | LXD host setup             |

## Roles

### Core Roles

| Role         | Replaces          | Description              |
| ------------ | ----------------- | ------------------------ |
| `common`     | prepare_ubuntu.sh | Locale, timezone, sysctl |
| `packages`   | libapt.sh         | APT package management   |
| `user_setup` | User functions    | User creation, SSH keys  |
| `bashrc`     | libbashrc.sh      | Shell configuration      |
| `rust`       | librust.sh        | Rust toolchain           |
| `cli_tools`  | CLI section       | mise, fzf, starship      |

### Desktop Roles

| Role          | Description           |
| ------------- | --------------------- |
| `desktop`     | GNOME settings, Nemo  |
| `i3wm`        | i3 window manager     |
| `kitty`       | Kitty terminal        |
| `firefox`     | Firefox browser       |
| `thunderbird` | Thunderbird email     |

### Application Roles

| Role     | Replaces           | Description     |
| -------- | ------------------ | --------------- |
| `r_node` | prepare_R-node.sh  | R, RStudio      |
| `lxd`    | make-lxd-node.sh   | LXD containers  |

## Usage

### Run Playbooks

```bash
# Using just
just run prepare_ubuntu
just run desktop

# Direct ansible-playbook
ansible-playbook playbooks/prepare_ubuntu.yml -i inventory/production/hosts.yml
```

### Check Mode (Dry Run)

```bash
just check prepare_ubuntu
```

### Using Tags

```bash
ansible-playbook playbooks/site.yml -i inventory/production/hosts.yml --tags "packages,bashrc"
```

## Development

### Linting

```bash
just lint          # ansible-lint
just lint-yaml     # yamllint
just validate      # all pre-commit hooks
```

### Testing

```bash
just test          # full molecule test
just test-converge # converge only
just test-verify   # verify only
just test-destroy  # cleanup
```

### Pre-commit Hooks

Configured hooks for all file types:

- YAML: yamllint, ansible-lint
- Shell: shellcheck, shfmt
- Markdown: markdownlint
- Jinja2: jinjalint
- Security: gitleaks
- General: trailing whitespace, EOF fixer

## Configuration

### Inventory Variables

Edit `inventory/production/group_vars/all.yml`:

```yaml
ansible_user: adam
packages_apt_proxy: ""
install_rust: true
install_cli_tools: true
```

### Role Variables

Each role has `defaults/main.yml` with configurable variables.

## Migration from Bash Scripts

| Bash Script            | Ansible Playbook   |
| ---------------------- | ------------------ |
| prepare_ubuntu.sh      | prepare_ubuntu.yml |
| prepare_ubuntu_user.sh | prepare_user.yml   |
| desktop-prepare.sh     | desktop.yml        |
| prepare_R-node.sh      | r_node.yml         |
| make-lxd-node.sh       | lxd_node.yml       |

## LXD E2E Testing

The project includes an LXD-based end-to-end test scenario for testing against
real Ubuntu containers instead of Docker.

### LXD Prerequisites

- LXD installed and initialized (`lxd init`)
- User added to `lxd` group
- Ubuntu 24.04 image available

### Running LXD E2E Tests

```bash
# Run full LXD E2E test cycle
just test-lxd-e2e

# Or run individual steps
just test-lxd-create    # Create test container
just test-lxd-converge  # Run playbooks
just test-lxd-verify    # Verify results
just test-lxd-destroy   # Cleanup
```

### LXD vs Docker Testing

| Feature | Docker (default) | LXD E2E |
|---------|-----------------|---------|
| Speed | Fast | Slower |
| Systemd | Limited | Full support |
| Realism | Container-like | VM-like |
| Use case | CI/CD | Integration testing |

## Troubleshooting

### Pre-commit Hook Failures

**ansible-lint fails with module not found:**

```bash
# Use local ansible-lint installation
pipx install ansible-lint
pre-commit run ansible-lint --all-files
```

**yamllint configuration errors:**

```bash
# Verify .yamllint exists and is valid
yamllint -c .yamllint .
```

### Molecule Test Issues

**Docker permission denied:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**Container fails to start:**

```bash
# Check Docker is running
sudo systemctl status docker

# Clean up old containers
just test-destroy
docker system prune -f
```

### Common Ansible Errors

**SSH connection refused:**

```bash
# Verify SSH key is loaded
ssh-add -l

# Test connection manually
ssh -v user@host
```

**Privilege escalation failed:**

```bash
# Ensure sudo is configured
ansible all -m ping -i inventory/production/hosts.yml --become
```

**Galaxy collection not found:**

```bash
# Install required collections
just galaxy
# Or manually:
ansible-galaxy collection install -r requirements.yml
```

### LXD Connectivity Issues

**Cannot connect to LXD socket:**

```bash
# Verify LXD is running
sudo systemctl status snap.lxd.daemon

# Check user is in lxd group
groups | grep lxd

# Re-login or use newgrp
newgrp lxd
```

**Container network issues:**

```bash
# Check LXD network
lxc network list
lxc network show lxdbr0

# Verify container has IP
lxc list
```

## License

MIT License
