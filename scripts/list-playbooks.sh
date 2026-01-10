#!/usr/bin/env bash
# List all Ansible playbooks with their purpose
# Extracts the description from the comment header of each playbook

set -euo pipefail

PLAYBOOKS_DIR="${1:-playbooks}"

# Colors for output
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RESET='\033[0m'

echo -e "${BOLD}Ansible Playbooks${RESET}"
echo "================="
echo ""

for playbook in "$PLAYBOOKS_DIR"/*.yml; do
    if [[ -f "$playbook" ]]; then
        filename=$(basename "$playbook")
        name="${filename%.yml}"

        # Extract the first comment block (lines starting with #) after ---
        # and get the first meaningful description line
        description=$(sed -n '/^---$/,/^[^#]/{/^# /p}' "$playbook" | head -1 | sed 's/^# //')

        if [[ -z "$description" ]]; then
            description="No description available"
        fi

        printf "${GREEN}%-20s${RESET} %s\n" "$name" "$description"
    fi
done

echo ""
