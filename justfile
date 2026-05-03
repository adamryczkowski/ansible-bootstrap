# Ansible Bootstrap - Task Runner
# https://just.systems/man/en/

# Default recipe - show available commands
default:
	@just --list

# Bootstrap the development environment
bootstrap:
	#!/usr/bin/env bash
	set -euo pipefail
	echo "=== Bootstrapping Ansible Bootstrap development environment ==="

	echo "Installing Ansible via pipx..."
	pipx install ansible --include-deps || pipx upgrade ansible

	echo "Installing Ansible Galaxy collections..."
	ansible-galaxy collection install -r requirements.yml --force

	echo "Installing Python development dependencies..."
	pip install -r requirements.txt

	echo "Setting up pre-commit hooks..."
	pre-commit install

	echo "=== Bootstrap complete! ==="

# Setup the development environment (alias for bootstrap)
setup: bootstrap

# Run all validation checks on ansible-bootstrap files
validate:
	#!/usr/bin/env bash
	set -euo pipefail
	echo "=== Running validation checks ==="

	echo "--- Running pre-commit on all files ---"
	pre-commit run --all-files

	echo "=== Validation complete ==="

# Format all files using available formatters
format:
	#!/usr/bin/env bash
	set -euo pipefail
	echo "=== Formatting files ==="

	echo "--- Fixing Markdown files ---"
	markdownlint --fix --disable MD013 MD033 MD041 -- *.md docs/*.md 2>/dev/null || true

	echo "--- Fixing shell scripts with shfmt ---"
	if command -v shfmt &> /dev/null; then
		find . -name "*.sh" -not -path "./collections/*" -exec shfmt -w -i 2 {} \;
	else
		echo "shfmt not installed, skipping shell script formatting"
	fi

	echo "=== Formatting complete ==="

# Run Molecule tests (default scenario with Docker)
test:
	molecule test

# Run LXD E2E test (mimics make-lxd-node.sh with --cli-improved)
test-lxd-e2e:
	molecule test -s lxd-e2e

# Run LXD E2E converge only (faster iteration)
test-lxd-e2e-converge:
	molecule converge -s lxd-e2e

# Run LXD E2E verify only
test-lxd-e2e-verify:
	molecule verify -s lxd-e2e

# Destroy LXD E2E test containers
test-lxd-e2e-destroy:
	molecule destroy -s lxd-e2e

# Run Claude Code LXD test (full lifecycle: create, converge, verify, destroy)
test-claude-code:
	molecule test -s claude-code

# Run Claude Code converge only (faster iteration)
test-claude-code-converge:
	molecule converge -s claude-code

# Run Claude Code verify only
test-claude-code-verify:
	molecule verify -s claude-code

# Destroy Claude Code test container
test-claude-code-destroy:
	molecule destroy -s claude-code

# Run Molecule converge only (faster iteration)
test-converge:
	molecule converge

# Run Molecule verify only
test-verify:
	molecule verify

# Destroy Molecule test containers
test-destroy:
	molecule destroy

# Run ansible-lint on all roles and playbooks
lint:
	ansible-lint roles/ playbooks/

# Run yamllint on all YAML files
lint-yaml:
	yamllint .

# Run shellcheck on all shell scripts
lint-shell:
	find . -name "*.sh" -not -path "./collections/*" -exec shellcheck {} \;

# Check syntax of all playbooks
syntax-check:
	ansible-playbook --syntax-check playbooks/*.yml

# List all available roles
list-roles:
	@ls -1 roles/

# List all available playbooks (simple list)
list-playbooks:
	@ls -1 playbooks/

# List all playbooks with their descriptions
playbooks:
	@./scripts/list-playbooks.sh

# Interactive playbook selector using fzf with live filtering, preview, and execution options
# Supports: local/remote execution, sudo password prompts, dry-run mode
select-playbook:
	@./scripts/select-playbook.sh playbooks

# Run a specific playbook against production inventory
run playbook inventory="inventory/production/hosts.yml":
	ansible-playbook playbooks/{{playbook}}.yml -i {{inventory}}

# Run a specific playbook in check mode (dry run)
check playbook inventory="inventory/production/hosts.yml":
	ansible-playbook playbooks/{{playbook}}.yml -i {{inventory}} --check --diff

# Run the claude_code playbook against a single host (multi-account enabled)
play-claude-code hostname:
	ansible-playbook playbooks/claude_code.yml --limit {{hostname}} \
		-e '{"claude_code_multi_account": {"enabled": true, "accounts": ["adam", "mik", "sofia"]}}'

# Rebuild claude-hierarchy on the controller and force-reinstall on a single host
upgrade-claude-hierarchy hostname:
	ansible-playbook playbooks/claude_hierarchy.yml --limit {{hostname}} \
		-e '{"claude_hierarchy_force_reinstall": true}'

# Bootstrap an Arch host: locale, user, bashrc, full CLI tools (rust + cli_tools).
# Pass the inventory containing the target host. Asks for sudo password.
prepare-arch inventory profile="full":
	ansible-playbook playbooks/prepare_arch.yml -i {{inventory}} \
		-e cli_tools_profile={{profile}} -K

# Deploy the full Sway desktop on the Lenovo Legion 9 (Arch).
# Includes desktop, sway, vscode roles. Asks for sudo password.
legion9-arch-setup:
	ansible-playbook playbooks/legion9-arch-setup.yml \
		-i inventory/legion9-arch/hosts.yml -K

# Install NVIDIA proprietary drivers (open kernel modules + prime-run +
# dynamic power management) on a single Arch host. Reboot afterwards.
nvidia-drivers inventory hostname:
	ansible-playbook playbooks/nvidia-drivers.yml -i {{inventory}} \
		--limit {{hostname}} -K

# Show Ansible configuration
config:
	ansible-config dump --only-changed

# Show inventory graph
inventory-graph inventory="inventory/production/hosts.yml":
	ansible-inventory -i {{inventory}} --graph

# Clean up generated files and caches
clean:
	rm -rf .molecule/
	rm -rf .cache/
	rm -rf collections/
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
