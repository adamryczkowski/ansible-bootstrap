# Conduwuit Matrix Homeserver — Deployment Plan

## Overview

Deploy conduwuit (lightweight Rust Matrix homeserver) as an Ansible role following
the `gotify_server` pattern: native binary in LXD container, systemd service,
no Docker.

**Source requirement**: `docs/feature-requests/matrix-server-deployment.md`

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Installation | Static binary (not Docker) | Matches gotify_server pattern, simpler |
| Container | LXD on local node (192.168.10.5) | Same infra as other services |
| Networking | Bridged (container gets LAN IP) | Direct access without proxy devices |
| Database | RocksDB (conduwuit default) | Only supported backend |
| Config format | TOML (`/etc/conduwuit/conduwuit.toml`) | conduwuit native format |
| TLS | Deferred (HTTP only for LAN test) | No external exposure yet |
| Federation | Disabled | Single-user bot server |
| Registration | Disabled | Accounts created via admin API |
| Binary source | `x86pup/conduwuit` GitHub releases | Current maintained repo |
| Binary asset | `static-x86_64-unknown-linux-musl` | Static, no deps needed |

## Role Structure: `conduwuit_server`

```text
roles/conduwuit_server/
├── defaults/main.yml          # All variables with defaults
├── handlers/main.yml          # Reload systemd, restart conduwuit
├── meta/main.yml              # Galaxy metadata
├── tasks/
│   ├── main.yml               # Entry point (includes sub-tasks in order)
│   ├── host.yml               # LXD container creation on host (Play 1)
│   ├── prerequisites.yml      # apt packages (curl)
│   ├── user.yml               # System user + directory tree
│   ├── install.yml            # Download static binary from GitHub
│   ├── configure.yml          # Render conduwuit.toml from template
│   ├── service.yml            # Systemd unit, enable + start
│   └── accounts.yml           # Create Matrix accounts + room via CS API
└── templates/
    ├── conduwuit.toml.j2      # Server configuration
    └── conduwuit.service.j2   # Systemd unit file
```

## Task Flow

### Play 1 — Host (192.168.10.5)

1. Create LXD container `conduwuit` with bridged profile (gets LAN IP)
2. Bootstrap Python3 inside container
3. Register container in in-memory inventory

### Play 2 — Inside Container

1. **prerequisites.yml** — install curl
2. **user.yml** — create `conduwuit` system user, dirs:
    - `/opt/conduwuit/` (install dir, 0755)
    - `/var/lib/conduwuit/` (database, 0700)
    - `/etc/conduwuit/` (config, 0750)
3. **install.yml** — download `static-x86_64-unknown-linux-musl` binary, stat guard
4. **configure.yml** — render `conduwuit.toml` with:
    - `server_name` (from variable)
    - `database_path = "/var/lib/conduwuit"`
    - `port = 6167`, `address = "0.0.0.0"`
    - `allow_registration = false`
    - `allow_federation = false`
    - `trusted_servers = []`
5. **service.yml** — deploy systemd unit, enable + start
6. **accounts.yml** — wait for healthcheck, create bot + human accounts via
    Matrix CS API, create private room, store access token

## Playbook: `playbooks/conduwuit.yml`

Two-play structure matching `playbooks/gotify.yml`:

- Play 1: Host preparation (LXD container with bridged networking)
- Play 2: Role application inside container

## Molecule Test: `molecule/conduwuit/`

Same pattern as `molecule/gotify/`:

- create.yml — LXD container creation
- converge.yml — run role (skip accounts.yml in test since no domain)
- verify.yml — assert binary, config, user, systemd, port listening
- destroy.yml — cleanup

## Key Variables

```yaml
conduwuit_version: "0.4.6"
conduwuit_server_name: "matrix.example.com"  # MUST override
conduwuit_port: 6167
conduwuit_address: "0.0.0.0"
conduwuit_database_path: "/var/lib/conduwuit"
conduwuit_allow_registration: false
conduwuit_allow_federation: false
conduwuit_max_request_size: 20971520
conduwuit_user: conduwuit
conduwuit_install_dir: /opt/conduwuit
conduwuit_config_dir: /etc/conduwuit
conduwuit_container_name: conduwuit
conduwuit_container_image: "24.04"
conduwuit_bot_user: "claude-bot"
conduwuit_bot_password: ""  # Vault
conduwuit_admin_user: "adam"
conduwuit_admin_password: ""  # Vault
conduwuit_room_name: "claude-hierarchy-notifications"
conduwuit_setup_accounts: false  # Enable for production
```

## Milestones

1. **Role skeleton** — defaults, meta, handlers, empty task files
2. **Host tasks** — LXD container creation with bridged networking
3. **Core tasks** — prerequisites, user, install, configure, service
4. **Templates** — conduwuit.toml.j2, conduwuit.service.j2
5. **Account setup** — Matrix CS API tasks for bot/human/room
6. **Playbook** — playbooks/conduwuit.yml
7. **Molecule tests** — create/converge/verify/destroy
8. **Test on 192.168.10.5** — deploy and verify

## Mobile Device Setup (for user)

After deployment:

1. Install Element app on phone (Play Store / App Store)
2. Open Element → "Sign in" → Custom server
3. Enter homeserver URL: `http://<container-ip>:6167`
4. Login as `adam` with configured password
5. Accept invite to `claude-hierarchy-notifications` room
6. Enable notifications in Element settings
7. Test: reply to a bot message using Element's reply feature (long-press → Reply)
