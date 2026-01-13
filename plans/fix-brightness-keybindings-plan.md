# Plan: Fix Brightness Key Bindings in Sway

## Problem Summary

After applying the Sway playbook to the remote machine `sofia@192.168.42.210`, pressing Fn+Brightness Up/Down (F5/F6) does not modify screen brightness. The `bright` tool is installed and works when called manually.

## Root Cause

The i3-config repository (`https://gitlab.com/adamwam/i3-config.git`) contains hardcoded absolute paths to `/home/adam/.local/bin/bright` in the sway and i3 configuration files. When deployed to a different user (e.g., `sofia`), these paths become invalid.

**Affected files in i3-config repository:**

- `sway/config` lines 269-272
- `i3/config` lines 276-280
- `albert/*.conf` (less critical)

## Recommended Solution

Implement a two-pronged approach:

1. **Immediate fix (Ansible):** Add post-processing task to replace hardcoded paths
2. **Long-term fix (i3-config repo):** Update the repository to use PATH-based resolution

---

## Implementation Plan

### Phase 1: Ansible Role Modification

#### Task 1.1: Add path replacement task to sway role

Add a new task file [`roles/sway/tasks/fix_hardcoded_paths.yml`](../roles/sway/tasks/fix_hardcoded_paths.yml) that:

- Uses `ansible.builtin.replace` module to replace `/home/adam` with the actual user's home directory
- Targets the cloned i3-config repository files
- Runs after the config.yml tasks

**Example task:**

```yaml
- name: Sway | Fix hardcoded home directory paths in sway config
  ansible.builtin.replace:
    path: "{{ sway_config_dest }}/sway/config"
    regexp: '/home/adam/'
    replace: '/home/{{ sway_username }}/'
  become: true
  become_user: "{{ sway_username }}"
```

#### Task 1.2: Add variable to control path fixing

Add a new variable to [`roles/sway/defaults/main.yml`](../roles/sway/defaults/main.yml):

```yaml
# Fix hardcoded paths in i3-config repository
# Replaces /home/adam with the actual user's home directory
sway_fix_hardcoded_paths: true
```

#### Task 1.3: Include the new task in main.yml

Add the include statement to [`roles/sway/tasks/main.yml`](../roles/sway/tasks/main.yml) after the config.yml include:

```yaml
- name: Sway | Include hardcoded path fixes
  ansible.builtin.include_tasks: fix_hardcoded_paths.yml
  when: sway_fix_hardcoded_paths | bool
```

### Phase 2: Remote Machine Fix (Immediate)

#### Task 2.1: Fix the remote machine manually

Apply a temporary fix on the remote machine `sofia@192.168.42.210` by replacing the hardcoded paths in the sway config.

**Command to execute (requires operator approval):**

```bash
sed -i 's|/home/adam/|/home/sofia/|g' ~/.config/i3-config/sway/config
```

#### Task 2.2: Reload sway configuration

After fixing the paths, reload the sway configuration:

```bash
swaymsg reload
```

### Phase 3: Long-term Fix (i3-config Repository)

#### Task 3.1: Update i3-config repository

Submit changes to the i3-config repository to use PATH-based resolution:

**Before:**

```text
bindsym XF86MonBrightnessUp exec /home/adam/.local/bin/bright +
```

**After:**

```text
bindsym XF86MonBrightnessUp exec bright +
```

This works because `~/.local/bin` is in the user's PATH when sway starts.

---

## Checklist

### Ansible Role Changes

- [ ] Create [`roles/sway/tasks/fix_hardcoded_paths.yml`](../roles/sway/tasks/fix_hardcoded_paths.yml)
- [ ] Add `sway_fix_hardcoded_paths` variable to [`roles/sway/defaults/main.yml`](../roles/sway/defaults/main.yml)
- [ ] Include fix_hardcoded_paths.yml in [`roles/sway/tasks/main.yml`](../roles/sway/tasks/main.yml)
- [ ] Update [`CHANGELOG.md`](../CHANGELOG.md) with the fix

### Remote Machine Fix

- [ ] Apply sed command to fix paths on sofia@192.168.42.210
- [ ] Reload sway configuration
- [ ] Test brightness keys work

### Long-term Fix

- [ ] Submit PR/MR to i3-config repository to use PATH-based resolution

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| sed command breaks config | Low | Medium | Backup config before running |
| Path replacement affects other valid paths | Low | Low | Use specific pattern `/home/adam/` |
| i3-config repo update breaks original author's setup | Low | Low | Discuss with author before submitting |

---

## Sources

1. [Arch Wiki - Sway](https://wiki.archlinux.org/title/Sway) - Best practices for sway configuration
2. Remote system investigation via SSH (documented in [`remote-work-log.md`](../remote-work-log.md))
