# SSH Keys - Central Repository of Operator Facts

This directory contains SSH public keys for operators who should have access to
managed hosts. These keys are deployed to target hosts during the user_setup
role execution.

## Adding a New Operator

1. Get the operator's public key (usually `~/.ssh/id_ed25519.pub`)
2. Save it to this directory with the naming convention: `user@hostname.pub`
3. Add the operator identifier to the `authorized_operators` list in
   `group_vars/all.yml` or the appropriate inventory group_vars

## Example

```bash
# Get the public key
cat ~/.ssh/id_ed25519.pub
# Output: ssh-ed25519 AAAAC3... user@hostname

# Save to this directory (inside the user_setup role)
echo "ssh-ed25519 AAAAC3... user@hostname" > roles/user_setup/files/ssh_keys/user@hostname.pub

# Update group_vars/all.yml (or inventory-specific group_vars)
authorized_operators:
  - user@hostname
```

## Current Operators

| Operator | Host | Description |
|----------|------|-------------|
| adam@legion9 | Local workstation | Primary development machine |
| adam@potwor | Remote server | Ansible controller for E2E tests |

## Security Notes

- These are **public** keys, so storing them in the repository is safe
- The corresponding **private** keys should never be stored in the repository
- Consider using SSH Certificate Authority (SSH CA) for larger deployments
