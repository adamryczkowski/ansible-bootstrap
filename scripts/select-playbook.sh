#!/usr/bin/env bash
# Interactive playbook selector using fzf
# Allows user to select a playbook with live filtering and preview
# Supports local and remote execution with sudo password handling

set -euo pipefail

PLAYBOOKS_DIR="${1:-playbooks}"
DEFAULT_INVENTORY="${2:-inventory/production/hosts.yml}"

# Colors
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Check if fzf is available
if ! command -v fzf &> /dev/null; then
    echo -e "${RED}Error: fzf is required for interactive selection but not installed.${RESET}"
    echo "Install with: sudo apt install fzf"
    exit 1
fi

# Build the list of playbooks with descriptions
get_playbook_list() {
    for playbook in "$PLAYBOOKS_DIR"/*.yml; do
        if [[ -f "$playbook" ]]; then
            filename=$(basename "$playbook")
            name="${filename%.yml}"

            # Extract the first comment line after ---
            description=$(sed -n '/^---$/,/^[^#]/{/^# /p}' "$playbook" | head -1 | sed 's/^# //')

            if [[ -z "$description" ]]; then
                description="No description available"
            fi

            printf "%-20s │ %s\n" "$name" "$description"
        fi
    done
}

# Preview function - show the playbook content
preview_cmd="bat --style=numbers --color=always --line-range=:50 $PLAYBOOKS_DIR/{1}.yml 2>/dev/null || cat $PLAYBOOKS_DIR/{1}.yml"

# Run fzf with preview
selected=$(get_playbook_list | fzf \
    --header="Select a playbook (type to filter, Enter to select, Esc to cancel)" \
    --preview="$preview_cmd" \
    --preview-window=right:60%:wrap \
    --ansi \
    --height=80% \
    --border=rounded \
    --prompt="Playbook> " \
    --pointer="▶" \
    --marker="✓" \
    --color="header:italic:underline" \
    || true)

if [[ -z "$selected" ]]; then
    echo "No playbook selected."
    exit 0
fi

# Extract playbook name (first column before │)
playbook_name=$(echo "$selected" | awk -F'│' '{print $1}' | xargs)

echo ""
echo -e "${GREEN}Selected playbook:${RESET} ${BOLD}$playbook_name${RESET}"
echo ""

# Ask user what they want to do
echo -e "${CYAN}What would you like to do?${RESET}"
echo ""
echo "  1) Run against local machine (localhost)"
echo "  2) Run against remote hosts (using inventory)"
echo "  3) Dry run (check mode) against remote hosts"
echo "  4) Show command only (don't execute)"
echo "  5) Cancel"
echo ""

read -rp "Select option [1-5]: " choice

case "$choice" in
    1)
        # Local execution
        echo ""
        echo -e "${YELLOW}Running against localhost...${RESET}"
        echo ""

        # Ask about sudo password
        echo -e "${CYAN}Does this playbook require sudo privileges?${RESET}"
        echo "  1) Yes, ask for sudo password (--ask-become-pass)"
        echo "  2) No, passwordless sudo is configured"
        echo ""
        read -rp "Select option [1-2]: " sudo_choice

        extra_args=""
        if [[ "$sudo_choice" == "1" ]]; then
            extra_args="--ask-become-pass"
        fi

        echo ""
        echo -e "${GREEN}Executing:${RESET}"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i localhost, --connection=local $extra_args"
        echo ""

        # shellcheck disable=SC2086
        ansible-playbook "playbooks/${playbook_name}.yml" -i "localhost," --connection=local $extra_args
        ;;
    2)
        # Remote execution with inventory
        echo ""
        echo -e "${CYAN}Available inventories:${RESET}"
        echo ""

        # List available inventories
        inventory_list=$(find inventory -name "hosts.yml" -o -name "hosts" 2>/dev/null | sort)

        if [[ -z "$inventory_list" ]]; then
            echo "No inventory files found in inventory/"
            exit 1
        fi

        # Use fzf to select inventory
        selected_inventory=$(echo "$inventory_list" | fzf \
            --header="Select inventory file" \
            --height=40% \
            --border=rounded \
            --prompt="Inventory> " \
            || echo "$DEFAULT_INVENTORY")

        if [[ -z "$selected_inventory" ]]; then
            selected_inventory="$DEFAULT_INVENTORY"
        fi

        echo ""
        echo -e "${YELLOW}Running against: ${selected_inventory}${RESET}"
        echo ""

        # Ask about sudo password
        echo -e "${CYAN}Does this playbook require sudo privileges?${RESET}"
        echo "  1) Yes, ask for sudo password (--ask-become-pass)"
        echo "  2) No, passwordless sudo is configured"
        echo ""
        read -rp "Select option [1-2]: " sudo_choice

        extra_args=""
        if [[ "$sudo_choice" == "1" ]]; then
            extra_args="--ask-become-pass"
        fi

        echo ""
        echo -e "${GREEN}Executing:${RESET}"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i ${selected_inventory} $extra_args"
        echo ""

        # shellcheck disable=SC2086
        ansible-playbook "playbooks/${playbook_name}.yml" -i "${selected_inventory}" $extra_args
        ;;
    3)
        # Dry run (check mode)
        echo ""
        echo -e "${CYAN}Available inventories:${RESET}"
        echo ""

        inventory_list=$(find inventory -name "hosts.yml" -o -name "hosts" 2>/dev/null | sort)

        if [[ -z "$inventory_list" ]]; then
            echo "No inventory files found in inventory/"
            exit 1
        fi

        selected_inventory=$(echo "$inventory_list" | fzf \
            --header="Select inventory file" \
            --height=40% \
            --border=rounded \
            --prompt="Inventory> " \
            || echo "$DEFAULT_INVENTORY")

        if [[ -z "$selected_inventory" ]]; then
            selected_inventory="$DEFAULT_INVENTORY"
        fi

        echo ""
        echo -e "${YELLOW}Dry run against: ${selected_inventory}${RESET}"
        echo ""

        # Ask about sudo password
        echo -e "${CYAN}Does this playbook require sudo privileges?${RESET}"
        echo "  1) Yes, ask for sudo password (--ask-become-pass)"
        echo "  2) No, passwordless sudo is configured"
        echo ""
        read -rp "Select option [1-2]: " sudo_choice

        extra_args="--check --diff"
        if [[ "$sudo_choice" == "1" ]]; then
            extra_args="$extra_args --ask-become-pass"
        fi

        echo ""
        echo -e "${GREEN}Executing:${RESET}"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i ${selected_inventory} $extra_args"
        echo ""

        # shellcheck disable=SC2086
        ansible-playbook "playbooks/${playbook_name}.yml" -i "${selected_inventory}" $extra_args
        ;;
    4)
        # Show command only
        echo ""
        echo -e "${CYAN}Commands to run this playbook:${RESET}"
        echo ""
        echo "  # Run against localhost:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i localhost, --connection=local"
        echo ""
        echo "  # Run against localhost with sudo password:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i localhost, --connection=local --ask-become-pass"
        echo ""
        echo "  # Run against remote hosts:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i inventory/production/hosts.yml"
        echo ""
        echo "  # Run against remote hosts with sudo password:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i inventory/production/hosts.yml --ask-become-pass"
        echo ""
        echo "  # Dry run (check mode):"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i inventory/production/hosts.yml --check --diff"
        echo ""
        echo "  # Using just:"
        echo "  just run ${playbook_name}"
        echo "  just check ${playbook_name}"
        echo ""
        ;;
    5|*)
        echo "Cancelled."
        exit 0
        ;;
esac
