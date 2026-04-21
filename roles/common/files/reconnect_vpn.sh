#!/bin/env bash
set -euo pipefail
#set -x

# Script that:
# 1. checks if internet is on by pinging 8.8.8.8
# 1a. if not - exits
# 2. if yes - checks if 192.168.10.10 is reachable
# 2a. if yes - exits
# 3. if not - checks if 192.168.42.1 is reachable
# 3a. if not - restarts VPN, and tries again. If not again - fails.
# 3b. if yes - executes `ip route add 192.168.10.0/24 via 192.168.42.10`

# All sudo-systemctl / dhclient / sshfs invocations are wrapped in `timeout`
# so a wedged softether oneshot (Type=oneshot stuck in `activating`) can
# never block this script indefinitely.

SUDO="sudo"
SYSTEMCTL_STOP_TIMEOUT=15
SYSTEMCTL_START_TIMEOUT=30
SYSTEMCTL_KILL_TIMEOUT=5
DHCLIENT_TIMEOUT=15
SSHFS_TIMEOUT=15

# Dynamically detect ALL softether*client systemd units (main + dom/aux).
detect_softether_services() {
    # All matching systemd units, one per line, in the order systemd returns them.
    # We rely on systemd dependency ordering (Requires=) at stop/start time.
    SOFTETHER_SYSTEMD_SERVICES=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null \
        | awk '{print $1}' \
        | grep -iE '^softether.*client.*\.service$' \
        || true)

    SOFTETHER_INITD_SERVICES=$(ls /etc/init.d/ 2>/dev/null | grep -iE '^softether.*client' || true)

    if [[ -z "$SOFTETHER_SYSTEMD_SERVICES" && -z "$SOFTETHER_INITD_SERVICES" ]]; then
        echo "WARNING: No SoftEther client services found on this system."
        return 1
    fi

    echo "Detected SoftEther services:"
    [[ -n "$SOFTETHER_SYSTEMD_SERVICES" ]] && echo "  systemd:" && echo "$SOFTETHER_SYSTEMD_SERVICES" | sed 's/^/    - /'
    [[ -n "$SOFTETHER_INITD_SERVICES" ]]   && echo "  init.d:"  && echo "$SOFTETHER_INITD_SERVICES"   | sed 's/^/    - /'
    return 0
}

# Detect VPN account from softether client config.
detect_vpn_account() {
    VPN_ACCOUNT=$(timeout 5 vpncmd localhost /CLIENT /CMD AccountList 2>/dev/null \
        | grep "VPN Connection Setting Name" \
        | awk -F'|' '{print $2}' | xargs \
        || true)

    if [[ -z "$VPN_ACCOUNT" ]]; then
        echo "WARNING: No VPN account found."
        return 1
    fi

    echo "Detected VPN account: $VPN_ACCOUNT"
    return 0
}

check_vpn_connected() {
    if [[ -z "${VPN_ACCOUNT:-}" ]]; then
        echo "No VPN account detected, cannot check connection status."
        return 1
    fi

    local status
    status=$(timeout 5 vpncmd localhost /CLIENT /CMD AccountStatusGet "$VPN_ACCOUNT" 2>/dev/null \
        | awk -F'|' '/Session Status/ {print $2}' | xargs || true)

    # Accept any of the "up" labels softether emits across versions.
    case "$status" in
        "Connection Completed"|"Session Established"|"Established") return 0 ;;
        *) return 1 ;;
    esac
}

# Any unit stuck in `activating` / `deactivating` / `failed` is killed hard
# and reset-failed, so subsequent stop/start calls do not hang.
clear_wedged_softether_services() {
    [[ -z "${SOFTETHER_SYSTEMD_SERVICES:-}" ]] && return 0

    local unit state
    while IFS= read -r unit; do
        [[ -z "$unit" ]] && continue
        state=$(systemctl show -p ActiveState --value "$unit" 2>/dev/null || echo "")
        case "$state" in
            activating|deactivating|failed)
                echo "  Unwedging $unit (state=$state): sending SIGKILL to cgroup"
                timeout "$SYSTEMCTL_KILL_TIMEOUT" $SUDO systemctl kill -s KILL "$unit" 2>/dev/null || true
                timeout "$SYSTEMCTL_KILL_TIMEOUT" $SUDO systemctl reset-failed "$unit" 2>/dev/null || true
                ;;
        esac
    done <<< "$SOFTETHER_SYSTEMD_SERVICES"
}

restart_softether_services() {
    echo "Restarting SoftEther VPN services..."

    # Kill anything wedged first so stop/start cannot hang on a stuck oneshot.
    clear_wedged_softether_services

    # Stop init.d service(s) (bounded).
    if [[ -n "${SOFTETHER_INITD_SERVICES:-}" ]]; then
        while IFS= read -r svc; do
            [[ -z "$svc" ]] && continue
            echo "  Stopping init.d service: $svc"
            timeout "$SYSTEMCTL_STOP_TIMEOUT" $SUDO service "$svc" stop || true
        done <<< "$SOFTETHER_INITD_SERVICES"
    fi

    # Stop systemd services in reverse order (dependents first).
    if [[ -n "${SOFTETHER_SYSTEMD_SERVICES:-}" ]]; then
        local reversed
        reversed=$(echo "$SOFTETHER_SYSTEMD_SERVICES" | tac)
        while IFS= read -r svc; do
            [[ -z "$svc" ]] && continue
            echo "  Stopping systemd service: $svc"
            timeout "$SYSTEMCTL_STOP_TIMEOUT" $SUDO systemctl stop "$svc" || {
                echo "    stop timed out — force killing"
                timeout "$SYSTEMCTL_KILL_TIMEOUT" $SUDO systemctl kill -s KILL "$svc" 2>/dev/null || true
                timeout "$SYSTEMCTL_KILL_TIMEOUT" $SUDO systemctl reset-failed "$svc" 2>/dev/null || true
            }
        done <<< "$reversed"

        # Start systemd services in forward order (dependencies first).
        while IFS= read -r svc; do
            [[ -z "$svc" ]] && continue
            echo "  Starting systemd service: $svc"
            timeout "$SYSTEMCTL_START_TIMEOUT" $SUDO systemctl start "$svc" || {
                echo "    start timed out or failed — leaving as-is and continuing"
            }
        done <<< "$SOFTETHER_SYSTEMD_SERVICES"
    fi

    # Start init.d service(s) last.
    if [[ -n "${SOFTETHER_INITD_SERVICES:-}" ]]; then
        while IFS= read -r svc; do
            [[ -z "$svc" ]] && continue
            echo "  Starting init.d service: $svc"
            timeout "$SYSTEMCTL_START_TIMEOUT" $SUDO service "$svc" start || true
        done <<< "$SOFTETHER_INITD_SERVICES"
    fi

    echo "  Waiting up to 15s for VPN session to establish..."
    local i
    for i in $(seq 1 15); do
        if check_vpn_connected; then
            echo "  VPN session established after ${i}s."
            return 0
        fi
        sleep 1
    done
    echo "  VPN session did not establish within 15s."
    return 1
}

# Detect services and account at script start.
detect_softether_services || true
detect_vpn_account || true

if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    echo "No internet connection. Exiting."
    exit 1
fi

if ! ping -c 1 -W 0.5 192.168.10.10 &>/dev/null; then

    if ! check_vpn_connected; then
        echo "VPN is not connected. Restarting VPN..."
        restart_softether_services || true

        if ! check_vpn_connected; then
            echo "VPN connection failed. Exiting."
            exit 1
        fi
    fi

    if ! ping -c 1 -W 0.5 192.168.42.1 &>/dev/null; then
        timeout "$DHCLIENT_TIMEOUT" $SUDO dhclient -1 vpn_dom || {
            echo "dhclient on vpn_dom timed out or failed."
            exit 1
        }
    fi

    echo "VPN is connected. Adding route to home network..."
    $SUDO ip route replace 192.168.10.0/24 via 192.168.42.10
    if ! ping -c 1 -W 0.5 192.168.10.10 &>/dev/null; then
        echo "ERROR! No connection to the home network. Is the VPN server running?"
        exit 0
    fi
else
    echo "Already connected to the home network"
fi

# Check if ~/mnt is mounted.
if $SUDO -u adam mountpoint -q /home/adam/mnt; then
    echo "mnt is already mounted"
else
    echo "Mounting ~/mnt using sshfs..."
    if ! timeout "$SSHFS_TIMEOUT" $SUDO -u adam sshfs \
        -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 \
        192.168.10.7:/pool88GB /home/adam/mnt; then
        echo "Failed to mount ~/mnt (timeout or error)."
        exit 1
    fi
fi
