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

# Dynamically detect SoftEther services
detect_softether_services() {
    # Find systemd services matching softether*client*
    SOFTETHER_SYSTEMD_SERVICES=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | \
        grep -i 'softether.*client' | awk '{print $1}' | head -n 1 || true)

    # Find init.d services matching softether*client*
    SOFTETHER_INITD_SERVICES=$(ls /etc/init.d/ 2>/dev/null | grep -i 'softether.*client' | head -n 1 || true)

    if [[ -z "$SOFTETHER_SYSTEMD_SERVICES" && -z "$SOFTETHER_INITD_SERVICES" ]]; then
        echo "WARNING: No SoftEther client services found on this system."
        return 1
    fi

    echo "Detected SoftEther services:"
    [[ -n "$SOFTETHER_SYSTEMD_SERVICES" ]] && echo "  - systemd: $SOFTETHER_SYSTEMD_SERVICES"
    [[ -n "$SOFTETHER_INITD_SERVICES" ]] && echo "  - init.d: $SOFTETHER_INITD_SERVICES"
    return 0
}

# Dynamically detect VPN account name
detect_vpn_account() {
    # Get the first VPN account from vpncmd
    # Format: "VPN Connection Setting Name |AccountName"
    VPN_ACCOUNT=$(vpncmd localhost /CLIENT /CMD AccountList 2>/dev/null | \
        grep "VPN Connection Setting Name" | awk -F'|' '{print $2}' | xargs || true)

    if [[ -z "$VPN_ACCOUNT" ]]; then
        echo "WARNING: No VPN account found."
        return 1
    fi

    echo "Detected VPN account: $VPN_ACCOUNT"
    return 0
}

# Check if VPN is connected
check_vpn_connected() {
    if [[ -z "${VPN_ACCOUNT:-}" ]]; then
        echo "No VPN account detected, cannot check connection status."
        return 1
    fi

    vpncmd localhost /CLIENT /CMD AccountStatusGet "$VPN_ACCOUNT" 2>/dev/null | \
        grep "Session Status" | grep -q "Connection Completed"
}

restart_softether_services() {
    echo "Restarting SoftEther VPN services..."

    # Stop init.d service first (if exists)
    if [[ -n "${SOFTETHER_INITD_SERVICES:-}" ]]; then
        echo "  Stopping init.d service: $SOFTETHER_INITD_SERVICES"
        sudo service "$SOFTETHER_INITD_SERVICES" stop || true
    fi

    # Stop and start systemd service (if exists)
    if [[ -n "${SOFTETHER_SYSTEMD_SERVICES:-}" ]]; then
        echo "  Restarting systemd service: $SOFTETHER_SYSTEMD_SERVICES"
        sudo systemctl stop "$SOFTETHER_SYSTEMD_SERVICES" || true
        sudo systemctl start "$SOFTETHER_SYSTEMD_SERVICES"
    fi

    # Start init.d service (if exists)
    if [[ -n "${SOFTETHER_INITD_SERVICES:-}" ]]; then
        echo "  Starting init.d service: $SOFTETHER_INITD_SERVICES"
        sudo service "$SOFTETHER_INITD_SERVICES" start
    fi

    # Wait for VPN to establish connection
    echo "  Waiting for VPN connection to establish..."
    sleep 5
}

# Detect services and account at script start
detect_softether_services || true
detect_vpn_account || true

if ! ping -c 1 8.8.8.8 &>/dev/null; then
    echo "No internet connection. Exiting."
    exit 1
fi

if ! ping -c 1 192.168.10.10 -W 0.5 &>/dev/null; then

    if ! check_vpn_connected; then
        echo "VPN is not connected. Restarting VPN..."
        restart_softether_services

        if ! check_vpn_connected; then
            echo "VPN connection failed. Exiting."
            exit 1
        fi
    fi

    if ! ping -c 1 192.168.42.1 -W 0.5 &>/dev/null; then
        sudo dhclient vpn_dom
    fi

    echo "VPN is connected. Adding route to home network..."
    ip route add 192.168.10.0/24 via 192.168.42.10
    if ! ping -c 1 192.168.10.10 -W 0.5 &>/dev/null; then
        echo "ERROR! No connection to the home network. Is the VPN server running?"
        exit 0
    fi
else
    echo "Already connected to the home network"
fi

# Check if ~/mnt is mounted
if sudo -u adam mountpoint -q /home/adam/mnt; then
    # If mounted, return
    echo "mnt is already mounted"
else
    # If not mounted, mount using sshfs
    echo "Mounting ~/mnt using sshfs..."
    sudo -u adam sshfs 192.168.10.7:/pool88GB /home/adam/mnt
    if [ $? -ne 0 ]; then
        # If mount fails, exit with error code
        echo "Failed to mount ~/mnt"
        exit 1
    fi
fi
