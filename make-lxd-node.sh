#!/bin/bash
# Create and configure an LXD container using Ansible playbooks.
#
# This is a CLI wrapper around the lxd_node.yml playbook, providing
# the same interface as the legacy puppet-bootstrap/make-lxd-node.sh.
#
# All container creation, user setup, SSH key injection, and
# configuration is handled by Ansible roles (lxd_container, user_setup,
# bashrc, cli_tools).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# =========================================================================
# Defaults
# =========================================================================
AUTOSTART=false
RELEASE="24.04"
USERNAME="$(whoami)"
SSH_USER="$(whoami)"
BRIDGE_IF=""
PRIVATE_KEY_PATH=""
PUBLIC_KEY_PATH=""
STATIC_IP=""
HOSTNAME_FQDN=""
BARE=false
CLI_PROFILE="full"
STORAGE=""
MAP_HOST_USER=""
MAP_HOST_FOLDER=""
MAP_GUEST_FOLDER=""
DEBUG=false
declare -a FORWARD_PORTS=()
declare -a AUTHORIZED_KEYS=()
declare -a EXTRA_ANSIBLE_ARGS=()

# =========================================================================
# Usage
# =========================================================================
usage() {
    cat <<'EOF'
Create and configure an LXD container via Ansible.

Usage:
    make-lxd-node.sh <container-name> [options]

Options:
    -r, --release <release>       Ubuntu release (default: 24.04)
    -a, --autostart               Enable autostart on host boot
    -u, --username <user>         Container username (default: current user)
    -s, --grant-ssh-access-to <user>
                                  Host user whose SSH key is injected (default: current user)
    --ip <address>                Set static IP address
    -h, --hostname <fqdn>        Hostname/FQDN for the container
    --bridgeif <interface>        Bridge interface (default: auto-detect LXD managed bridge)
    --private-key-path <path>     Install this private key in the container
    --public-key-path <path>      Install this public key in the container
    --authorized-key <key>        Additional SSH public key (repeatable)
    --map-host-user <user>        Map host user's uid/gid into container
    --map-host-folder <host> <guest>
                                  Share a host folder into the container
    --forward-port <spec>         Forward port (e.g. tcp:0.0.0.0:8080;80)
    --storage <pool>              LXD storage pool (default: from profile)
    --bare                        Minimal setup (SSH + locale only, skip CLI tools)
    --cli-profile <profile>       CLI tools profile: minimal or full (default: full)
    --debug                       Enable verbose Ansible output
    --help                        Show this help

Examples:
    ./make-lxd-node.sh mynode --autostart --bridgeif br0
    ./make-lxd-node.sh devbox --release 24.04 --bare --ip 192.168.10.50
    ./make-lxd-node.sh workstation --map-host-folder /data /mnt/data --autostart
EOF
}

# =========================================================================
# Parse arguments
# =========================================================================
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi

CONTAINER_NAME="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            DEBUG=true
            ;;
        -h|--hostname)
            HOSTNAME_FQDN="$2"
            shift
            ;;
        -a|--autostart)
            AUTOSTART=true
            ;;
        -u|--username)
            USERNAME="$2"
            shift
            ;;
        --bare)
            BARE=true
            CLI_PROFILE="minimal"
            ;;
        --cli-profile)
            CLI_PROFILE="$2"
            shift
            ;;
        --forward-port)
            FORWARD_PORTS+=("$2")
            shift
            ;;
        --storage)
            STORAGE="$2"
            shift
            ;;
        --authorized-key)
            AUTHORIZED_KEYS+=("$2")
            shift
            ;;
        --ip)
            STATIC_IP="$2"
            shift
            ;;
        -r|--release)
            RELEASE="$2"
            shift
            ;;
        -s|--grant-ssh-access-to)
            SSH_USER="$2"
            shift
            ;;
        --bridgeif)
            BRIDGE_IF="$2"
            shift
            ;;
        --map-host-user)
            MAP_HOST_USER="$2"
            shift
            ;;
        --map-host-folder)
            MAP_HOST_FOLDER="$2"
            MAP_GUEST_FOLDER="$3"
            shift 2
            ;;
        --private-key-path)
            PRIVATE_KEY_PATH="$2"
            shift
            ;;
        --public-key-path)
            PUBLIC_KEY_PATH="$2"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

# =========================================================================
# Build container config
# =========================================================================
CONFIG='{"security.nesting": "true"}'
if [[ "$AUTOSTART" == "true" ]]; then
    CONFIG=$(echo "$CONFIG" | python3 -c "import sys,json; d=json.load(sys.stdin); d['boot.autostart']='true'; print(json.dumps(d))")
fi

# =========================================================================
# Build container devices
# =========================================================================
DEVICES='{}'

# Bridge interface
if [[ -n "$BRIDGE_IF" ]]; then
    # Check if it's an LXD-managed bridge or external
    if lxc network list 2>/dev/null | grep -qE "\\| ${BRIDGE_IF} .*\\| bridge.*\\| YES"; then
        # LXD-managed bridge — use network attach style
        DEVICES=$(python3 -c "
import json
d = json.loads('$DEVICES')
d['eth0'] = {'type': 'nic', 'network': '$BRIDGE_IF', 'name': 'eth0'}
print(json.dumps(d))")
    else
        # External bridge — use nictype=bridged
        DEVICES=$(python3 -c "
import json
d = json.loads('$DEVICES')
d['eth0'] = {'type': 'nic', 'nictype': 'bridged', 'parent': '$BRIDGE_IF', 'name': 'eth0'}
print(json.dumps(d))")
    fi
fi

# Static IP
if [[ -n "$STATIC_IP" ]]; then
    DEVICES=$(python3 -c "
import json
d = json.loads('$DEVICES')
if 'eth0' not in d:
    d['eth0'] = {'type': 'nic', 'name': 'eth0'}
d['eth0']['ipv4.address'] = '$STATIC_IP'
print(json.dumps(d))")
fi

# Map host folder
if [[ -n "$MAP_HOST_FOLDER" ]]; then
    SHARE_NAME=$(basename "$MAP_HOST_FOLDER")
    DEVICES=$(python3 -c "
import json
d = json.loads('$DEVICES')
d['$SHARE_NAME'] = {'type': 'disk', 'source': '$MAP_HOST_FOLDER', 'path': '$MAP_GUEST_FOLDER'}
print(json.dumps(d))")
fi

# Storage pool
STORAGE_JSON=""
if [[ -n "$STORAGE" ]]; then
    DEVICES=$(python3 -c "
import json
d = json.loads('$DEVICES')
d['root'] = {'type': 'disk', 'path': '/', 'pool': '$STORAGE'}
print(json.dumps(d))")
fi

# Port forwarding
for port_spec in "${FORWARD_PORTS[@]}"; do
    # Parse tcp:0.0.0.0:8080;80
    if [[ "$port_spec" =~ ^(tcp|udp):([^:]+):([0-9]+)\;([0-9]+)$ ]]; then
        PROTO="${BASH_REMATCH[1]}"
        ADDR="${BASH_REMATCH[2]}"
        HOST_PORT="${BASH_REMATCH[3]}"
        CONTAINER_PORT="${BASH_REMATCH[4]}"
        FWD_NAME="forward${PROTO}${HOST_PORT}"
        DEVICES=$(python3 -c "
import json
d = json.loads('$DEVICES')
d['$FWD_NAME'] = {
    'type': 'proxy',
    'listen': '${PROTO}:${ADDR}:${HOST_PORT}',
    'connect': '${PROTO}:127.0.0.1:${CONTAINER_PORT}'
}
print(json.dumps(d))")
    else
        echo "Error: Cannot parse forward-port spec: $port_spec" >&2
        exit 1
    fi
done

# =========================================================================
# Build uid/gid mapping
# =========================================================================
if [[ -n "$MAP_HOST_USER" ]]; then
    HOST_UID=$(id -u "$MAP_HOST_USER")
    HOST_GID=$(id -g "$MAP_HOST_USER")
    if [[ "$HOST_UID" == "$HOST_GID" ]]; then
        CONFIG=$(python3 -c "
import json
d = json.loads('$CONFIG')
d['raw.idmap'] = 'both $HOST_UID 1001'
print(json.dumps(d))")
    else
        CONFIG=$(python3 -c "
import json
d = json.loads('$CONFIG')
d['raw.idmap'] = 'uid $HOST_UID 1001\ngid $HOST_GID 1001'
print(json.dumps(d))")
    fi
fi

# =========================================================================
# Resolve SSH key
# =========================================================================
SSH_HOME=$(getent passwd "$SSH_USER" | cut -d: -f6)
SSH_PUBKEY_FILE="${SSH_HOME}/.ssh/id_ed25519.pub"

if [[ ! -f "$SSH_PUBKEY_FILE" ]]; then
    echo "SSH key not found for $SSH_USER. Generating..."
    ssh-keygen -q -t ed25519 -N "" -a 100 -f "${SSH_HOME}/.ssh/id_ed25519"
fi

# =========================================================================
# Build extra vars JSON
# =========================================================================
HOSTNAME_FQDN="${HOSTNAME_FQDN:-$CONTAINER_NAME}"

# Build bare flag for Python
if [[ "$BARE" == "true" ]]; then
    BARE_PY="True"
else
    BARE_PY="False"
fi

# Build authorized keys JSON array
AUTH_KEYS_JSON="[]"
if [[ ${#AUTHORIZED_KEYS[@]} -gt 0 ]]; then
    AUTH_KEYS_JSON=$(printf '%s\n' "${AUTHORIZED_KEYS[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
fi

EXTRA_VARS=$(python3 <<PYEOF
import json

extra = {
    'lxd_node_container_name': '${CONTAINER_NAME}',
    'lxd_node_release': '${RELEASE}',
    'lxd_node_username': '${USERNAME}',
    'lxd_node_hostname': '${HOSTNAME_FQDN}',
    'lxd_node_config': json.loads('${CONFIG}'),
    'lxd_node_devices': json.loads('${DEVICES}'),
    'lxd_node_ssh_pubkey_file': '${SSH_PUBKEY_FILE}',
    'lxd_node_bare': ${BARE_PY},
    'cli_tools_profile': '${CLI_PROFILE}',
}

if '${PRIVATE_KEY_PATH}':
    extra['lxd_node_private_key_path'] = '${PRIVATE_KEY_PATH}'
if '${PUBLIC_KEY_PATH}':
    extra['lxd_node_public_key_path'] = '${PUBLIC_KEY_PATH}'

auth_keys = json.loads('${AUTH_KEYS_JSON}')
if auth_keys:
    extra['lxd_node_authorized_keys'] = auth_keys

print(json.dumps(extra))
PYEOF
)

# =========================================================================
# Run Ansible
# =========================================================================
ANSIBLE_ARGS=(
    "-i" "localhost,"
    "-c" "local"
    "-e" "$EXTRA_VARS"
)

if [[ "$DEBUG" == "true" ]]; then
    ANSIBLE_ARGS+=("-vv")
fi

echo "Creating LXD container '$CONTAINER_NAME'..."
echo "  Release:    Ubuntu $RELEASE"
echo "  Username:   $USERNAME"
echo "  Autostart:  $AUTOSTART"
echo "  Bridge:     ${BRIDGE_IF:-auto (default profile)}"
echo "  CLI tools:  $CLI_PROFILE"
echo ""

exec ansible-playbook "$SCRIPT_DIR/playbooks/make_lxd_node.yml" "${ANSIBLE_ARGS[@]}"
