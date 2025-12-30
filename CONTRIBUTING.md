# Contributing to Ansible Bootstrap

Thank you for your interest in contributing to Ansible Bootstrap! This document
provides guidelines and instructions for contributing.

## Development Setup

### Prerequisites

- Ubuntu 22.04+ or compatible Linux distribution
- Python 3.10+
- Docker (for Molecule testing)
- LXD (optional, for E2E testing)

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/ansible-bootstrap.git
cd ansible-bootstrap

# Bootstrap development environment
just bootstrap

# Verify setup
just validate
```

### Required Tools

The bootstrap process installs:

- `pipx` - Python application installer
- `ansible` - Configuration management
- `ansible-lint` - Ansible linter
- `molecule` - Testing framework
- `pre-commit` - Git hooks manager
- `just` - Task runner

## Code Style Guidelines

### YAML Files

- Use 2-space indentation
- Always use explicit `true`/`false` for booleans
- Quote strings containing special characters
- Follow yamllint rules defined in `.yamllint`

### Ansible Best Practices

- Use fully qualified collection names (FQCN)
- Prefix role variables with role name (e.g., `kitty_font_size`)
- Use `ansible.builtin.` prefix for built-in modules
- Add `changed_when` and `failed_when` to command/shell tasks
- Include meaningful task names with role prefix

### Variable Naming

```yaml
# Good - prefixed with role name
kitty_font_size: 11
rust_packages:
  - atuin
  - zoxide

# Bad - generic names
font_size: 11
packages:
  - atuin
```

### Task Documentation

Add header comments to complex task files:

```yaml
---
# Role Name - Brief description
#
# Purpose:
#   Detailed explanation of what this role does.
#
# Key Variables:
#   - var_name: Description (default: value)
#
# Dependencies:
#   - other_role
#
# Example Usage:
#   - role: role_name
#     vars:
#       var_name: value
```

## Pull Request Process

### Before Submitting

Create a feature branch for your changes:

```bash
git checkout -b feature/your-feature-name
```

Make your changes following the code style guidelines, then run validation:

```bash
just validate
```

Run the test suite:

```bash
just test
```

Commit with a descriptive message:

```bash
git commit -m "feat(role): Add new feature description"
```

### Commit Message Format

Follow conventional commits format:

```text
type(scope): description

[optional body]

[optional footer]
```

Types:

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code style changes (formatting, etc.)
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks

Examples:

```text
feat(kitty): Add Nerd Fonts installation
fix(lxd): Correct preseed configuration syntax
docs(readme): Add troubleshooting section
```

### Pull Request Template

When creating a PR, include:

- **Description:** What does this PR do?
- **Related Issue:** Link to related issue if applicable
- **Testing:** How was this tested?
- **Checklist:**
  - [ ] `just validate` passes
  - [ ] `just test` passes
  - [ ] Documentation updated if needed
  - [ ] Commit messages follow convention

## Testing Requirements

### All Changes Must Pass

```bash
# Pre-commit hooks (linting, formatting)
just validate

# Molecule tests (Docker-based)
just test
```

### Adding New Roles

When adding a new role, create the role structure:

```bash
mkdir -p roles/new_role/{tasks,defaults,meta,handlers,templates,files}
```

Then add the following files:

- `meta/main.yml` with Galaxy metadata
- `defaults/main.yml` with documented variables
- Tasks with proper documentation
- Update `molecule/default/converge.yml` to include the role
- Add verification tests to `molecule/default/verify.yml`

### Testing with LXD

For changes requiring systemd or full OS testing:

```bash
just test-lxd-e2e
```

## Directory Structure

```text
roles/
└── role_name/
    ├── defaults/
    │   └── main.yml      # Default variables (documented)
    ├── files/            # Static files
    ├── handlers/
    │   └── main.yml      # Handlers
    ├── meta/
    │   └── main.yml      # Galaxy metadata
    ├── tasks/
    │   └── main.yml      # Main tasks (with header docs)
    └── templates/        # Jinja2 templates
```

## Getting Help

- Open an issue for bugs or feature requests
- Check existing issues before creating new ones
- Use discussions for questions and ideas

## License

By contributing, you agree that your contributions will be licensed under the
MIT License.
