#!/bin/bash
# Script to discover the D-Bus session bus address for a given user
# This is useful for running gsettings commands as root for a specific user

set -euo pipefail

USER="${1:-$USER}"

# Try to find the session bus address from the user's environment
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    echo "$DBUS_SESSION_BUS_ADDRESS"
    exit 0
fi

# Try to get it from the user's session
PID=$(pgrep -u "$USER" -x gnome-session 2>/dev/null || pgrep -u "$USER" -x gnome-shell 2>/dev/null || pgrep -u "$USER" -x dbus-daemon 2>/dev/null | head -1)

if [ -n "${PID:-}" ]; then
    DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/"$PID"/environ 2>/dev/null | tr '\0' '\n' | cut -d= -f2-)
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        echo "$DBUS_SESSION_BUS_ADDRESS"
        exit 0
    fi
fi

# Fallback: try the standard socket location
SOCKET_PATH="/run/user/$(id -u "$USER")/bus"
if [ -S "$SOCKET_PATH" ]; then
    echo "unix:path=$SOCKET_PATH"
    exit 0
fi

echo "Could not discover D-Bus session bus address for user $USER" >&2
exit 1
