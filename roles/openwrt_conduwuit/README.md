# openwrt_conduwuit

Ansible role to deploy [conduwuit](https://github.com/continuwuity/continuwuity)
Matrix homeserver on an aarch64 OpenWRT router using Docker.

## Overview

- **Deployment**: Docker (`ghcr.io/continuwuity/continuwuity:v0.5.3`, arm64)
- **TLS**: Let's Encrypt via DNS-01 (Cloudflare) with `acme-acmesh`
- **Proxy**: `nginx-ssl` on ports 443 (client) and 8448 (federation)
- **DDNS**: `ddns-scripts-cloudflare` updates `matrix.statystyka.net` A record
- **Service**: procd init script wraps `docker compose up -d` / `docker compose down`
- **Server name**: `statystyka.net` (Matrix IDs: `@user:statystyka.net`)

## Requirements

- aarch64 OpenWRT router (tested on 24.10.4)
- Docker installed and running on the router
- SSH access as root (`root@192.168.10.10`)
- Cloudflare API token (DNS edit permissions) and Zone ID
- Ansible Vault configured for secret variables

## Quick Start

```bash
# Deploy
ansible-playbook playbooks/openwrt_conduwuit.yml -i inventory/openwrt_conduwuit

# Deploy with account creation
ansible-playbook playbooks/openwrt_conduwuit.yml -i inventory/openwrt_conduwuit \
  -e openwrt_conduwuit_setup_accounts=true

# Dry run
ansible-playbook playbooks/openwrt_conduwuit.yml -i inventory/openwrt_conduwuit --check

# Run a specific section only
ansible-playbook playbooks/openwrt_conduwuit.yml -i inventory/openwrt_conduwuit \
  --tags openwrt_conduwuit_preflight
```

## Secrets Setup

Encrypt secrets with Ansible Vault and place them in
`inventory/openwrt_conduwuit/group_vars/openwrt_conduwuit.yml`:

```bash
ansible-vault encrypt_string 'your-api-token' --name openwrt_conduwuit_cloudflare_api_token
ansible-vault encrypt_string 'your-zone-id' --name openwrt_conduwuit_cloudflare_zone_id
ansible-vault encrypt_string 'admin-password' --name openwrt_conduwuit_admin_password
ansible-vault encrypt_string 'bot-password' --name openwrt_conduwuit_bot_password
```

## Account Management

Matrix accounts are created during deployment when
`openwrt_conduwuit_setup_accounts: true` is set. The role:

1. Temporarily enables registration with a random token
2. Creates the admin account (`adam` by default)
3. Creates the bot account (`claude-bot` by default)
4. Creates the `family-notifications` room and invites both accounts
5. Disables registration (returns HTTP 403 for new registrations)
6. Writes credentials to `/opt/conduwuit/.env.matrix` (mode 0600)

**To create accounts after initial deployment:**

```bash
ansible-playbook playbooks/openwrt_conduwuit.yml -i inventory/openwrt_conduwuit \
  -e openwrt_conduwuit_setup_accounts=true \
  --tags openwrt_conduwuit_accounts
```

**To change a password:**

```bash
# SSH to the router, then use the Matrix admin API:
curl -X PUT \
  "http://127.0.0.1:6167/_matrix/client/v3/account/password" \
  -H "Authorization: Bearer <admin_access_token>" \
  -H "Content-Type: application/json" \
  -d '{"new_password": "new-password", "logout_devices": false}'
```

**Bot credentials** are stored in `/opt/conduwuit/.env.matrix`:

```bash
cat /opt/conduwuit/.env.matrix
# MATRIX_HOMESERVER_URL=https://matrix.statystyka.net
# MATRIX_ACCESS_TOKEN=<token>
# MATRIX_ROOM_ID=<room_id>
# MATRIX_USER_ID=@claude-bot:statystyka.net
# MATRIX_OWNER_USER_ID=@adam:statystyka.net
```

## Connecting Element X

[Element X](https://element.io/element-x) is the recommended Matrix client.
It supports sliding sync natively (built-in to conduwuit — no additional
configuration required).

**iOS / Android setup:**

1. Open Element X and tap **Sign in**
2. Select **Other homeserver**
3. Enter homeserver URL: `https://matrix.statystyka.net`
4. Log in with your Matrix username and password

**Verify connection:**

The `.well-known` endpoints delegate `statystyka.net` to `matrix.statystyka.net`:

```bash
curl https://statystyka.net/.well-known/matrix/client
# {"m.homeserver":{"base_url":"https://matrix.statystyka.net"}}

curl https://statystyka.net/.well-known/matrix/server
# {"m.server":"matrix.statystyka.net:443"}
```

**Note:** If `statystyka.net` is served by a different web server, the
`.well-known` files must be manually deployed there. conduwuit's built-in
`[global.well_known]` only serves them at `matrix.statystyka.net`.

## Inviting Family Members

Family members can join the `family-notifications` room after you invite them.

### Option 1: Invite via Element X

1. Open the `family-notifications` room
2. Tap the room name → **Invite people**
3. Enter the Matrix ID: `@username:statystyka.net` (for users on this server)
  or `@username:matrix.org` (for users on other servers)

### Option 2: Invite via Admin API

```bash
# Get admin access token from .env.matrix
source /opt/conduwuit/.env.matrix

# Invite a user to the room
curl -X POST \
  "http://127.0.0.1:6167/_matrix/client/v3/rooms/${MATRIX_ROOM_ID}/invite" \
  -H "Authorization: Bearer ${MATRIX_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "@family-member:matrix.org"}'
```

**Note:** Registration is disabled by default (`allow_registration: false`).
New local accounts must be created using the admin API or by re-running
the accounts task.

## Troubleshooting

### Container not starting

```bash
# SSH to the router
ssh root@192.168.10.10

# Check container status
docker ps -a --filter name=conduwuit

# View container logs
docker logs conduwuit

# Start container manually
docker compose -f /opt/conduwuit/docker-compose.yml up -d

# Check procd service
/etc/init.d/conduwuit status
```

### TLS certificate issues

```bash
# Check certificate expiry
openssl x509 -in /etc/acme/matrix.statystyka.net/fullchain.cer -noout -enddate

# Manually renew certificate
/etc/init.d/acme restart

# Check ACME logs
logread | grep acme
```

### nginx configuration issues

```bash
# Validate nginx configuration
nginx -t

# Check nginx status
/etc/init.d/nginx status

# View nginx error log
logread | grep nginx

# Reload nginx
/etc/init.d/nginx reload
```

### DDNS not updating

```bash
# Check current WAN IP
curl -s ifconfig.me

# Check DNS resolution
nslookup matrix.statystyka.net 1.1.1.1

# View DDNS logs
logread | grep ddns

# Manually trigger DDNS update
/usr/lib/ddns/dynamic_dns_updater.sh -S matrix_ddns start
```

### Matrix API not responding

```bash
# Check if conduwuit is listening
curl -s http://127.0.0.1:6167/_matrix/client/versions | head -c 200

# Check federation endpoint
curl -s http://127.0.0.1:6167/_matrix/federation/v1/version

# Check sliding sync endpoint (should return 401, not 404)
curl -s -o /dev/null -w '%{http_code}' \
  -X POST http://127.0.0.1:6167/_matrix/client/unstable/org.matrix.simplified_msc3575/sync \
  -H 'Content-Type: application/json' -d '{}'

# Check conduwuit logs
docker logs conduwuit --tail 50
```

### Firewall blocking external access

```bash
# Verify firewall rules exist
uci show firewall | grep matrix

# Check nftables rules
nft list ruleset | grep -E 'dport (443|8448)'

# Test from outside the network
curl -v https://matrix.statystyka.net/_matrix/client/versions
```

### Idempotency failures

If the second playbook run reports changed tasks, check:

1. `conduwuit.toml` or `docker-compose.yml` being regenerated — verify
  template variables are stable (no `ansible_date_time` in templates)
2. Docker image being re-pulled — the `install.yml` task should be
  idempotent (only pulls if image absent)
3. DDNS service state changes — the ddns service may report `changed`
  if UCI config is being re-applied

Run with `--check --diff` to see what is changing:

```bash
ansible-playbook playbooks/openwrt_conduwuit.yml -i inventory/openwrt_conduwuit --check --diff
```
