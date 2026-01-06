# Code Review Action Plan - Ansible Bootstrap

**Created:** December 30, 2025
**Based on:** [Code Review Findings](code-review-findings.md)

## Overview

This document outlines a structured plan to address the findings from the code review. The plan is organized into milestones, prioritized by severity and impact.

---

## Milestone 1: Critical Fixes (Immediate)

**Priority:** Critical
**Estimated Effort:** 1-2 hours
**Goal:** Fix issues that prevent core functionality from working

### 1.1 Fix Pre-commit Configuration File Pattern

**Finding:** P-01, V-02
**File:** `.pre-commit-config.yaml`

**Current State:**

```yaml
files: ^ansible-bootstrap/
```

**Action:**

1. Remove the `files:` directive entirely (line 12), or change it to:

```yaml
files: ''
```

1. Update all `exclude:` patterns to remove the `^ansible-bootstrap/` prefix:

- Line 29: `exclude: ^collections/`
- Line 50: `exclude: ^collections/`
- Line 58: `exclude: ^collections/`
- Line 80: `exclude: ^collections/`
- Line 88: `exclude: ^collections/`

1. Fix config file paths in hooks:

- Line 49: Change `args: [-c, ansible-bootstrap/.yamllint]` to `args: [-c, .yamllint]`
- Line 57: Change `args: [-c, ansible-bootstrap/.ansible-lint]` to `args: [-c, .ansible-lint]`

### 1.2 Fix ansible-lint Pre-commit Hook Compatibility

**Finding:** P-02, V-03
**File:** `.pre-commit-config.yaml`

**Action:**

1. Update ansible-lint hook to use local installation instead of pre-commit's isolated environment:

```yaml
- repo: local
  hooks:
    - id: ansible-lint
      name: Ansible-lint
      entry: ansible-lint
      language: system
      files: \.(yml|yaml)$
      exclude: ^collections/
      args: [-c, .ansible-lint]
```

Or alternatively, pin to a compatible version and ensure ansible is available:

```yaml
- repo: https://github.com/ansible/ansible-lint
  rev: v24.12.2
  hooks:
    - id: ansible-lint
      additional_dependencies:
        - ansible-core>=2.15
      args: [-c, .ansible-lint]
      exclude: ^collections/
```

---

## Milestone 2: High Priority Fixes

**Priority:** High
**Estimated Effort:** 2-3 hours
**Goal:** Fix significant issues affecting functionality

### 2.1 Fix Variable Naming Convention Violation

**Finding:** Q-01, V-01
**File:** `roles/user_setup/defaults/main.yml`

**Action:**

1. Rename `authorized_operators` to `user_setup_authorized_operators` in:

- `roles/user_setup/defaults/main.yml` (line 29)
- `roles/user_setup/tasks/main.yml` (lines 47, 51)

1. Update any inventory files or playbooks that reference this variable

### 2.2 Fix Molecule LXD E2E Verification Script Path

**Finding:** B-02
**Files:** `molecule/lxd-e2e/verify.yml`, `roles/cli_tools/tasks/main.yml`

**Action:**
Either:

1. Update `molecule/lxd-e2e/verify.yml` line 178 to check for `90_mise.sh`:

```yaml
path: "/home/{{ target_user }}/.bashrc.d/90_mise.sh"
```

Or:

1. Update `roles/cli_tools/tasks/main.yml` line 44 to use `10_mise.sh`:

```yaml
dest: "/home/{{ cli_tools_username }}/.bashrc.d/10_mise.sh"
```

---

## Milestone 3: Project Instrumentation

**Priority:** Medium
**Estimated Effort:** 2-3 hours
**Goal:** Add missing justfile actions and improve validation

### 3.1 Add Missing Justfile Actions

**Finding:** I-01, I-02
**File:** `justfile`

**Action:** Add the following recipes to `justfile`:

```just
# Setup the development environment (alias for bootstrap)
setup: bootstrap

# Format all files using available formatters
format:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Formatting files ==="

    echo "--- Fixing YAML files with yamllint suggestions ---"
    # Note: yamllint doesn't auto-fix, but we can use other tools

    echo "--- Fixing Markdown files ---"
    markdownlint --fix --disable MD013 MD033 MD041 -- *.md docs/*.md || true

    echo "--- Fixing shell scripts with shfmt ---"
    if command -v shfmt &> /dev/null; then
        find . -name "*.sh" -not -path "./collections/*" -exec shfmt -w -i 2 {} \;
    fi

    echo "=== Formatting complete ==="
```

### 3.2 Improve Validate Action

**Finding:** I-03, I-04
**File:** `justfile`

**Action:** Update the `validate` recipe to properly fail on errors and run pre-commit:

```just
# Run all validation checks on ansible-bootstrap files
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Running validation checks ==="

    echo "--- Running pre-commit on all files ---"
    pre-commit run --all-files

    echo "=== Validation complete ==="
```

Or if you want more granular control:

```just
# Run all validation checks on ansible-bootstrap files
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    FAILED=0
    echo "=== Running validation checks ==="

    echo "--- yamllint ---"
    yamllint -c .yamllint . || FAILED=1

    echo "--- ansible-lint ---"
    ansible-lint -c .ansible-lint roles/ playbooks/ || FAILED=1

    echo "--- markdownlint ---"
    markdownlint --disable MD013 MD033 MD041 -- *.md || FAILED=1

    echo "--- shellcheck ---"
    find . -name "*.sh" -not -path "./collections/*" -exec shellcheck {} \; || FAILED=1

    echo "=== Validation complete ==="
    exit $FAILED
```

### 3.3 Add Shell Linting Action

**Finding:** I-05
**File:** `justfile`

**Action:** Add shellcheck recipe:

```just
# Run shellcheck on all shell scripts
lint-shell:
    find . -name "*.sh" -not -path "./collections/*" -exec shellcheck {} \;
```

---

## Milestone 4: Pre-commit Hook Improvements

**Priority:** Medium
**Estimated Effort:** 2-3 hours
**Goal:** Add missing hooks and enable security scanning

### 4.1 Add Shell Script Hooks

**Finding:** P-06, P-07
**File:** `.pre-commit-config.yaml`

**Action:** Add shellcheck and shfmt hooks:

```yaml
# Shell script linting and formatting
- repo: https://github.com/shellcheck-py/shellcheck-py
  rev: v0.9.0.6
  hooks:
    - id: shellcheck
      args: [--severity=warning]

- repo: https://github.com/scop/pre-commit-shfmt
  rev: v3.8.0-1
  hooks:
    - id: shfmt
      args: [-i, '2', -ci]
```

### 4.2 Add Jinja2 Linting Hook

**Finding:** P-08
**File:** `.pre-commit-config.yaml`

**Action:** Add j2lint hook for Jinja2 templates:

```yaml
# Jinja2 linting
- repo: https://github.com/aristanetworks/j2lint
  rev: v1.1.0
  hooks:
    - id: j2lint
      files: \.j2$
```

### 4.3 Enable Security Scanning

**Finding:** P-05
**File:** `.pre-commit-config.yaml`

**Action:** Uncomment and configure gitleaks:

```yaml
# Secret detection
- repo: https://github.com/gitleaks/gitleaks
  rev: v8.21.2
  hooks:
    - id: gitleaks
```

If network issues persist, consider using a local installation:

```yaml
- repo: local
  hooks:
    - id: gitleaks
      name: gitleaks
      entry: gitleaks protect --staged --verbose
      language: system
      pass_filenames: false
```

---

## Milestone 5: Bug Fixes

**Priority:** Medium
**Estimated Effort:** 3-4 hours
**Goal:** Fix potential bugs and improve error handling

### 5.1 Fix LXD Preseed Command

**Finding:** B-01
**File:** `roles/lxd/tasks/main.yml`

**Action:** Replace the shell command with a safer approach:

```yaml
- name: LXD | Apply preseed configuration
  ansible.builtin.shell: lxd init --preseed < /tmp/lxd-preseed.yaml
  args:
    executable: /bin/bash
  become: true
  changed_when: true
  register: lxd_preseed_result
  failed_when: lxd_preseed_result.rc != 0
```

### 5.2 Improve Rust Package Installation Error Handling

**Finding:** B-05
**File:** `roles/rust/tasks/main.yml`

**Action:** Add proper error handling and logging:

```yaml
- name: Rust | Install Rust packages via binstall
  ansible.builtin.command: >
    /home/{{ rust_username }}/.cargo/bin/cargo binstall --no-confirm {{ item }}
  loop: "{{ rust_packages }}"
  become: true
  become_user: "{{ rust_username }}"
  register: rust_binstall_result
  changed_when: "'Installed' in rust_binstall_result.stdout"
  failed_when:
    - rust_binstall_result.rc != 0
    - "'already installed' not in rust_binstall_result.stderr"
  environment:
    HOME: "/home/{{ rust_username }}"
    PATH: "/home/{{ rust_username }}/.cargo/bin:{{ ansible_env.PATH }}"
  when: rust_packages | length > 0 and rust_install_binstall | bool
```

### 5.3 Make Nerd Fonts Version Configurable

**Finding:** B-07
**File:** `roles/kitty/defaults/main.yml`, `roles/kitty/tasks/main.yml`

**Action:**

1. Add variable to `roles/kitty/defaults/main.yml`:

```yaml
# Nerd Fonts version
kitty_nerd_fonts_version: "v3.3.0"
```

1. Update `roles/kitty/tasks/main.yml`:

```yaml
- name: Kitty | Download JetBrains Mono Nerd Font
  ansible.builtin.unarchive:
    src: "https://github.com/ryanoasis/nerd-fonts/releases/download/{{ kitty_nerd_fonts_version }}/JetBrainsMono.zip"
    dest: "/home/{{ kitty_username }}/.local/share/fonts/"
    remote_src: true
```

---

## Milestone 6: Code Quality Improvements

**Priority:** Low
**Estimated Effort:** 4-5 hours
**Goal:** Improve code consistency and documentation

### 6.1 Add Missing Meta Files

**Finding:** S-01
**Files:** `roles/common/meta/main.yml`, `roles/bashrc/meta/main.yml`, `roles/rust/meta/main.yml`

**Action:** Create meta files for roles missing them. Example for `roles/common/meta/main.yml`:

```yaml
---
# Common role metadata

galaxy_info:
  author: Adam
  description: Base system configuration (locale, timezone, sysctl)
  company: ""
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: Ubuntu
      versions:
        - jammy
        - noble

dependencies: []
```

### 6.2 Standardize Username Variable Usage

**Finding:** Q-02
**Files:** Multiple playbooks and roles

**Action:**

1. Document the variable hierarchy in README:

- `target_user`: Inventory-level variable for the target username
- `<role>_username`: Role-specific variable that defaults to `target_user`

1. Ensure all roles follow the pattern:

```yaml
# In defaults/main.yml
<role>_username: "{{ target_user | default(ansible_user) | default('adam') }}"
```

### 6.3 Add Role Documentation

**Finding:** Q-04
**Files:** All role task files

**Action:** Add header comments to complex task files explaining:

- Purpose of the role
- Key variables
- Dependencies
- Example usage

---

## Milestone 7: Documentation Improvements

**Priority:** Low
**Estimated Effort:** 2-3 hours
**Goal:** Improve project documentation

### 7.1 Add Troubleshooting Section to README

**Finding:** R-02
**File:** `README.md`

**Action:** Add a troubleshooting section covering:

- Pre-commit hook failures
- Molecule test issues
- Common Ansible errors
- LXD connectivity issues

### 7.2 Add Contributing Guidelines

**Finding:** R-04
**File:** `CONTRIBUTING.md`

**Action:** Create a CONTRIBUTING.md file with:

- Development setup instructions
- Code style guidelines
- Pull request process
- Testing requirements

### 7.3 Add Changelog

**Finding:** R-03
**File:** `CHANGELOG.md`

**Action:** Create a CHANGELOG.md following Keep a Changelog format.

### 7.4 Document LXD E2E Testing

**Finding:** R-06
**File:** `README.md`

**Action:** Add section explaining:

- LXD E2E test scenario purpose
- How to run LXD tests
- Requirements (LXD installed and configured)

---

## Implementation Schedule

| Milestone | Priority | Effort | Suggested Timeline |
|-----------|----------|--------|-------------------|
| 1. Critical Fixes | Critical | 1-2h | Immediate |
| 2. High Priority Fixes | High | 2-3h | Within 1 day |
| 3. Project Instrumentation | Medium | 2-3h | Within 1 week |
| 4. Pre-commit Improvements | Medium | 2-3h | Within 1 week |
| 5. Bug Fixes | Medium | 3-4h | Within 2 weeks |
| 6. Code Quality | Low | 4-5h | Within 1 month |
| 7. Documentation | Low | 2-3h | Within 1 month |

**Total Estimated Effort:** 16-23 hours

---

## Verification Checklist

After implementing fixes, verify:

- [ ] `pre-commit run --all-files` passes without errors
- [ ] `just validate` passes without errors
- [ ] `just test` (Molecule Docker tests) passes
- [ ] `just test-lxd-e2e` passes (if LXD is available)
- [ ] All justfile actions (`setup`, `format`, `test`, `validate`) work correctly
- [ ] README accurately reflects current project state
- [ ] No ansible-lint warnings at `moderate` profile level

---

## Notes

1. **Web Research Required:** Before implementing pre-commit hook changes, verify the latest versions of:

- shellcheck-py
- pre-commit-shfmt
- j2lint
- gitleaks

1. **Testing:** After each milestone, run the full validation suite to ensure no regressions.

1. **Git:** Do not commit changes until all tests pass. Consider using feature branches for each milestone.
