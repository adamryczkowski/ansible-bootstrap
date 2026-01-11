#!/usr/bin/env bash
# Interactive playbook selector using fzf
# Allows user to select a playbook with live filtering and preview
# Supports local and remote execution with sudo password handling
# Includes Python interpreter detection for local execution

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

# Check if jq is available (needed for parsing ansible-inventory output)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for parsing inventory data but not installed.${RESET}"
    echo "Install with: sudo apt install jq"
    exit 1
fi

# Function to validate host name for Ansible inventory
# Ansible host names should only contain alphanumeric characters, hyphens, and underscores
# Spaces and special characters are not allowed (Ansible's --limit flag treats spaces as separators)
validate_host_name() {
    local name="$1"
    if [[ -z "$name" ]]; then
        return 1
    fi
    # Check if name matches valid pattern: starts with letter/number, contains only alphanumeric, hyphen, underscore
    if [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a Python interpreter has working cffi_backend
check_python_cffi() {
    local python_path="$1"
    "$python_path" -c "import _cffi_backend" 2>/dev/null
}

# Function to find all available Python interpreters
find_python_interpreters() {
    local interpreters=()

    # Check common Python paths
    for py in python3 python python3.12 python3.11 python3.10 python3.9; do
        if command -v "$py" &> /dev/null; then
            local path
            path=$(command -v "$py")
            # Avoid duplicates by resolving symlinks
            local real_path
            real_path=$(readlink -f "$path" 2>/dev/null || echo "$path")
            if [[ ! " ${interpreters[*]:-} " =~ " ${real_path} " ]]; then
                interpreters+=("$path")
            fi
        fi
    done

    # Check pyenv versions if available
    if command -v pyenv &> /dev/null; then
        while IFS= read -r version; do
            local pyenv_python
            pyenv_python="$(pyenv root)/versions/$version/bin/python"
            if [[ -x "$pyenv_python" ]]; then
                interpreters+=("$pyenv_python")
            fi
        done < <(pyenv versions --bare 2>/dev/null || true)
    fi

    # Check mise/asdf Python versions
    if [[ -d "$HOME/.local/share/mise/installs/python" ]]; then
        for version_dir in "$HOME/.local/share/mise/installs/python"/*; do
            if [[ -x "$version_dir/bin/python" ]]; then
                interpreters+=("$version_dir/bin/python")
            fi
        done
    fi

    # Check system Python locations
    for py in /usr/bin/python3 /usr/bin/python /usr/local/bin/python3; do
        if [[ -x "$py" ]] && [[ ! " ${interpreters[*]:-} " =~ " ${py} " ]]; then
            interpreters+=("$py")
        fi
    done

    printf '%s\n' "${interpreters[@]}"
}

# Function to select a working Python interpreter for local execution
select_python_interpreter() {
    local default_python
    default_python=$(command -v python3 || command -v python || echo "")

    if [[ -z "$default_python" ]]; then
        echo -e "${RED}Error: No Python interpreter found.${RESET}"
        return 1
    fi

    # Check if default Python has working cffi
    if check_python_cffi "$default_python"; then
        echo "$default_python"
        return 0
    fi

    echo -e "${YELLOW}Warning: Default Python ($default_python) has broken cffi_backend module.${RESET}"
    echo -e "${CYAN}Searching for working Python interpreters...${RESET}"
    echo ""

    # Find all interpreters and check which ones work
    local working_interpreters=()
    local broken_interpreters=()

    while IFS= read -r interpreter; do
        if [[ -n "$interpreter" ]]; then
            if check_python_cffi "$interpreter"; then
                local version
                version=$("$interpreter" --version 2>&1 | head -1)
                working_interpreters+=("$interpreter ($version)")
            else
                broken_interpreters+=("$interpreter")
            fi
        fi
    done < <(find_python_interpreters)

    if [[ ${#working_interpreters[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No Python interpreter with working cffi_backend found.${RESET}"
        echo ""
        echo "Broken interpreters found:"
        for interp in "${broken_interpreters[@]}"; do
            echo "  - $interp"
        done
        echo ""
        echo "To fix this, try one of:"
        echo "  1. Install python3-cffi: sudo apt install python3-cffi"
        echo "  2. Reinstall cryptography: pip install --force-reinstall cryptography"
        echo "  3. Use a different Python version via pyenv or mise"
        return 1
    fi

    if [[ ${#working_interpreters[@]} -eq 1 ]]; then
        # Only one working interpreter, use it
        local selected="${working_interpreters[0]}"
        local python_path="${selected%% (*}"
        echo -e "${GREEN}Found working Python: $selected${RESET}"
        echo "$python_path"
        return 0
    fi

    # Multiple working interpreters, let user choose
    echo -e "${CYAN}Select a Python interpreter:${RESET}"
    echo ""

    local selected
    selected=$(printf '%s\n' "${working_interpreters[@]}" | fzf \
        --header="Select a working Python interpreter" \
        --height=40% \
        --border=rounded \
        --prompt="Python> " \
        || echo "")

    if [[ -z "$selected" ]]; then
        echo -e "${RED}No interpreter selected.${RESET}"
        return 1
    fi

    # Extract path from "path (version)" format
    local python_path="${selected%% (*}"
    echo "$python_path"
}

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
echo "  3) Run against remote hosts (specified manually)"
echo "  4) Dry run (check mode) against remote hosts"
echo "  5) Show command only (don't execute)"
echo "  6) Cancel"
echo ""

read -rp "Select option [1-6]: " choice

case "$choice" in
    1)
        # Local execution
        echo ""
        echo -e "${YELLOW}Running against localhost...${RESET}"
        echo ""

        # Check Python interpreter for local execution
        python_interpreter=$(select_python_interpreter) || exit 1

        # Ask about sudo password
        echo ""
        echo -e "${CYAN}Does this playbook require sudo privileges?${RESET}"
        echo "  1) Yes, ask for sudo password (--ask-become-pass)"
        echo "  2) No, passwordless sudo is configured"
        echo ""
        read -rp "Select option [1-2]: " sudo_choice

        extra_args="-e ansible_python_interpreter=$python_interpreter"
        if [[ "$sudo_choice" == "1" ]]; then
            extra_args="$extra_args --ask-become-pass"
        fi

        echo ""
        echo -e "${GREEN}Executing:${RESET}"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i localhost, --connection=local $extra_args"
        echo ""

        # shellcheck disable=SC2086
        ansible-playbook "playbooks/${playbook_name}.yml" -i "localhost," --connection=local $extra_args
        ;;
    2)
        # Remote execution with inventory - tree view of inventories and hosts
        echo ""
        echo -e "${CYAN}Select target (inventory or specific host):${RESET}"
        echo ""

        # Build tree-view list of all inventories and their hosts
        tree_list=""

        # Find all inventory files
        while IFS= read -r inv_file; do
            if [[ -n "$inv_file" ]]; then
                # Add inventory file as a selectable item
                tree_list="${tree_list}📁 ${inv_file}"$'\n'

                # Get inventory JSON once and extract hosts with their IPs
                inv_json=$(ansible-inventory -i "$inv_file" --list 2>/dev/null)
                while IFS= read -r host_name; do
                    if [[ -n "$host_name" ]]; then
                        # Use jq to extract ansible_host from the cached JSON
                        host_ip=$(echo "$inv_json" | jq -r "._meta.hostvars[\"$host_name\"].ansible_host // empty" 2>/dev/null || echo "")
                        if [[ -n "$host_ip" ]]; then
                            tree_list="${tree_list}  └─ ${host_name} (${host_ip}) [${inv_file}]"$'\n'
                        else
                            tree_list="${tree_list}  └─ ${host_name} [${inv_file}]"$'\n'
                        fi
                    fi
                done < <(ansible-inventory -i "$inv_file" --graph 2>/dev/null | grep -v '@' | sed 's/.*|--//' | sed 's/^[[:space:]]*//' | sort -u)
            fi
        done < <(find inventory -name "hosts.yml" -o -name "hosts" 2>/dev/null | sort)

        if [[ -z "$tree_list" ]]; then
            echo "No inventory files found in inventory/"
            exit 1
        fi

        # Use fzf to select from tree view
        selected_item=$(echo -e "$tree_list" | grep -v '^$' | fzf \
            --header="Select inventory (all hosts) or specific host" \
            --height=60% \
            --border=rounded \
            --prompt="Target> " \
            --ansi \
            || echo "")

        if [[ -z "$selected_item" ]]; then
            echo "No target selected. Cancelled."
            exit 0
        fi

        # Parse the selection
        selected_inventory=""
        limit_host=""
        limit_ip=""
        target_display=""

        if [[ "$selected_item" == "📁 "* ]]; then
            # Selected an inventory file - run against all hosts in it
            selected_inventory=$(echo "$selected_item" | sed 's/📁 //')
            target_display="all hosts in ${selected_inventory}"
        elif [[ "$selected_item" == "  └─ "* ]]; then
            # Selected a specific host - extract host name, IP, and inventory
            # Format: "  └─ hostname (IP) [inventory/path/hosts.yml]"
            host_part=$(echo "$selected_item" | sed 's/  └─ //')
            # Extract inventory path from [...]
            selected_inventory=$(echo "$host_part" | grep -o '\[.*\]' | tr -d '[]')
            # Extract host name (before the IP or inventory bracket)
            limit_host=$(echo "$host_part" | sed 's/ (.*//' | sed 's/ \[.*//')
            # Extract IP address if present (inside parentheses)
            if [[ "$host_part" =~ \(([0-9.]+)\) ]]; then
                limit_ip="${BASH_REMATCH[1]}"
            fi
            target_display="host: ${limit_host}"
        fi

        echo ""
        echo -e "${YELLOW}Running against: ${target_display}${RESET}"
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
        if [[ -n "$limit_host" ]]; then
            # Use host name for --limit (must match inventory host name, not ansible_host IP)
            echo "  ansible-playbook playbooks/${playbook_name}.yml -i ${selected_inventory} --limit '${limit_host}' $extra_args"
            if [[ -n "$limit_ip" ]]; then
                echo "  (host ${limit_host} -> ${limit_ip})"
            fi
            echo ""
            # shellcheck disable=SC2086
            ansible-playbook "playbooks/${playbook_name}.yml" -i "${selected_inventory}" --limit "${limit_host}" $extra_args
        else
            echo "  ansible-playbook playbooks/${playbook_name}.yml -i ${selected_inventory} $extra_args"
            echo ""
            # shellcheck disable=SC2086
            ansible-playbook "playbooks/${playbook_name}.yml" -i "${selected_inventory}" $extra_args
        fi
        ;;
    3)
        # Remote execution with manually specified host
        echo ""
        echo -e "${CYAN}Enter remote host details:${RESET}"
        echo ""

        # Get host address
        read -rp "Host address (IP or hostname): " remote_host
        if [[ -z "$remote_host" ]]; then
            echo -e "${RED}Error: Host address is required.${RESET}"
            exit 1
        fi

        # Get SSH user
        read -rp "SSH username [$(whoami)]: " remote_user
        if [[ -z "$remote_user" ]]; then
            remote_user=$(whoami)
        fi

        # Get SSH port
        read -rp "SSH port [22]: " remote_port
        if [[ -z "$remote_port" ]]; then
            remote_port="22"
        fi

        # Get target user (user to configure on the remote host)
        read -rp "Target user (user to configure) [$remote_user]: " target_user
        if [[ -z "$target_user" ]]; then
            target_user="$remote_user"
        fi

        # Ask about SSH key or password authentication
        echo ""
        echo -e "${CYAN}SSH authentication method:${RESET}"
        echo "  1) Use SSH key (default)"
        echo "  2) Ask for SSH password"
        echo ""
        read -rp "Select option [1-2]: " auth_choice

        # Ask about sudo password
        echo ""
        echo -e "${CYAN}Does this playbook require sudo privileges?${RESET}"
        echo "  1) Yes, ask for sudo password (--ask-become-pass)"
        echo "  2) No, passwordless sudo is configured"
        echo ""
        read -rp "Select option [1-2]: " sudo_choice

        # Build extra args
        extra_args="-e target_user=$target_user -e ansible_port=$remote_port"
        if [[ "$auth_choice" == "2" ]]; then
            extra_args="$extra_args --ask-pass"
        fi
        if [[ "$sudo_choice" == "1" ]]; then
            extra_args="$extra_args --ask-become-pass"
        fi

        echo ""
        echo -e "${YELLOW}Running against: ${remote_user}@${remote_host}:${remote_port}${RESET}"
        echo ""

        echo -e "${GREEN}Executing:${RESET}"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i ${remote_host}, -u ${remote_user} $extra_args"
        echo ""

        # shellcheck disable=SC2086
        ansible-playbook "playbooks/${playbook_name}.yml" -i "${remote_host}," -u "${remote_user}" $extra_args

        # Ask if user wants to add this host to inventory
        echo ""
        echo -e "${CYAN}Would you like to add this host to the inventory?${RESET}"
        echo "  1) Yes"
        echo "  2) No"
        echo ""
        read -rp "Select option [1-2]: " add_to_inventory

        if [[ "$add_to_inventory" == "1" ]]; then
            # Get host name for inventory with validation
            echo ""
            echo -e "${CYAN}Host name requirements:${RESET}"
            echo "  - Must start with a letter or number"
            echo "  - Can only contain letters, numbers, hyphens (-), and underscores (_)"
            echo "  - No spaces or special characters allowed"
            echo ""
            while true; do
                read -rp "Enter a name for this host in the inventory: " host_name
                if [[ -z "$host_name" ]]; then
                    echo -e "${RED}Error: Host name is required.${RESET}"
                    continue
                fi
                if ! validate_host_name "$host_name"; then
                    echo -e "${RED}Error: Invalid host name '$host_name'.${RESET}"
                    echo "Host names must start with a letter/number and contain only alphanumeric characters, hyphens, and underscores."
                    continue
                fi
                break
            done

            # Select inventory file
            echo ""
            echo -e "${CYAN}Select inventory file:${RESET}"
            inventory_list=$(find inventory -name "hosts.yml" 2>/dev/null | sort)

            if [[ -z "$inventory_list" ]]; then
                echo "No inventory files found in inventory/"
                exit 1
            fi

            selected_inventory=$(echo "$inventory_list" | fzf \
                --header="Select inventory file to add host to" \
                --height=40% \
                --border=rounded \
                --prompt="Inventory> " \
                || echo "")

            if [[ -z "$selected_inventory" ]]; then
                echo "No inventory selected. Skipping."
            else
                # Extract groups from the inventory file
                echo ""
                echo -e "${CYAN}Select group to add host to:${RESET}"

                # Parse groups from the inventory file (children of 'all')
                groups=$(grep -E "^    [a-zA-Z_][a-zA-Z0-9_-]*:$" "$selected_inventory" | sed 's/://g' | xargs)

                if [[ -z "$groups" ]]; then
                    echo "No groups found in inventory file."
                    exit 1
                fi

                selected_group=$(echo "$groups" | tr ' ' '\n' | fzf \
                    --header="Select group" \
                    --height=40% \
                    --border=rounded \
                    --prompt="Group> " \
                    || echo "")

                if [[ -z "$selected_group" ]]; then
                    echo "No group selected. Skipping."
                else
                    # Add host to the inventory file
                    # Find the line with the group's hosts: section and add the new host
                    echo ""
                    echo -e "${YELLOW}Adding host to ${selected_inventory} in group ${selected_group}...${RESET}"

                    # Create the host entry
                    host_entry="        ${host_name}:\n          ansible_host: ${remote_host}\n          ansible_user: ${remote_user}\n          target_user: ${target_user}"
                    if [[ "$remote_port" != "22" ]]; then
                        host_entry="${host_entry}\n          ansible_port: ${remote_port}"
                    fi

                    # Find the line number of the group's hosts: section
                    # We need to find the pattern "    groupname:\n      hosts:" and insert after "hosts:"
                    group_line=$(grep -n "^    ${selected_group}:$" "$selected_inventory" | cut -d: -f1)

                    if [[ -z "$group_line" ]]; then
                        echo -e "${RED}Error: Could not find group ${selected_group} in inventory.${RESET}"
                        exit 1
                    fi

                    # Find the hosts: line after the group
                    hosts_line=$(tail -n +"$group_line" "$selected_inventory" | grep -n "^      hosts:$" | head -1 | cut -d: -f1)

                    if [[ -z "$hosts_line" ]]; then
                        echo -e "${RED}Error: Could not find hosts section for group ${selected_group}.${RESET}"
                        exit 1
                    fi

                    # Calculate the actual line number
                    insert_line=$((group_line + hosts_line - 1))

                    # Create a temporary file with the new content
                    {
                        head -n "$insert_line" "$selected_inventory"
                        echo -e "$host_entry"
                        tail -n +"$((insert_line + 1))" "$selected_inventory"
                    } > "${selected_inventory}.tmp"

                    mv "${selected_inventory}.tmp" "$selected_inventory"

                    echo -e "${GREEN}Host ${host_name} added to ${selected_inventory} in group ${selected_group}.${RESET}"
                fi
            fi
        fi
        ;;
    4)
        # Dry run (check mode) - tree view of inventories and hosts
        echo ""
        echo -e "${CYAN}Select target (inventory or specific host):${RESET}"
        echo ""

        # Build tree-view list of all inventories and their hosts
        tree_list=""

        while IFS= read -r inv_file; do
            if [[ -n "$inv_file" ]]; then
                tree_list="${tree_list}📁 ${inv_file}"$'\n'

                # Get inventory JSON once and extract hosts with their IPs
                inv_json=$(ansible-inventory -i "$inv_file" --list 2>/dev/null)
                while IFS= read -r host_name; do
                    if [[ -n "$host_name" ]]; then
                        # Use jq to extract ansible_host from the cached JSON
                        host_ip=$(echo "$inv_json" | jq -r "._meta.hostvars[\"$host_name\"].ansible_host // empty" 2>/dev/null || echo "")
                        if [[ -n "$host_ip" ]]; then
                            tree_list="${tree_list}  └─ ${host_name} (${host_ip}) [${inv_file}]"$'\n'
                        else
                            tree_list="${tree_list}  └─ ${host_name} [${inv_file}]"$'\n'
                        fi
                    fi
                done < <(ansible-inventory -i "$inv_file" --graph 2>/dev/null | grep -v '@' | sed 's/.*|--//' | sed 's/^[[:space:]]*//' | sort -u)
            fi
        done < <(find inventory -name "hosts.yml" -o -name "hosts" 2>/dev/null | sort)

        if [[ -z "$tree_list" ]]; then
            echo "No inventory files found in inventory/"
            exit 1
        fi

        selected_item=$(echo -e "$tree_list" | grep -v '^$' | fzf \
            --header="Select inventory (all hosts) or specific host for dry run" \
            --height=60% \
            --border=rounded \
            --prompt="Target> " \
            --ansi \
            || echo "")

        if [[ -z "$selected_item" ]]; then
            echo "No target selected. Cancelled."
            exit 0
        fi

        selected_inventory=""
        limit_host=""
        limit_ip=""
        target_display=""

        if [[ "$selected_item" == "📁 "* ]]; then
            selected_inventory=$(echo "$selected_item" | sed 's/📁 //')
            target_display="all hosts in ${selected_inventory}"
        elif [[ "$selected_item" == "  └─ "* ]]; then
            host_part=$(echo "$selected_item" | sed 's/  └─ //')
            selected_inventory=$(echo "$host_part" | grep -o '\[.*\]' | tr -d '[]')
            limit_host=$(echo "$host_part" | sed 's/ (.*//' | sed 's/ \[.*//')
            # Extract IP address if present (inside parentheses)
            if [[ "$host_part" =~ \(([0-9.]+)\) ]]; then
                limit_ip="${BASH_REMATCH[1]}"
            fi
            target_display="host: ${limit_host}"
        fi

        echo ""
        echo -e "${YELLOW}Dry run against: ${target_display}${RESET}"
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
        if [[ -n "$limit_host" ]]; then
            # Use host name for --limit (must match inventory host name, not ansible_host IP)
            echo "  ansible-playbook playbooks/${playbook_name}.yml -i ${selected_inventory} --limit '${limit_host}' $extra_args"
            if [[ -n "$limit_ip" ]]; then
                echo "  (host ${limit_host} -> ${limit_ip})"
            fi
            echo ""
            # shellcheck disable=SC2086
            ansible-playbook "playbooks/${playbook_name}.yml" -i "${selected_inventory}" --limit "${limit_host}" $extra_args
        else
            echo "  ansible-playbook playbooks/${playbook_name}.yml -i ${selected_inventory} $extra_args"
            echo ""
            # shellcheck disable=SC2086
            ansible-playbook "playbooks/${playbook_name}.yml" -i "${selected_inventory}" $extra_args
        fi
        ;;
    5)
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
        echo "  # Run against localhost with specific Python interpreter:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i localhost, --connection=local -e ansible_python_interpreter=/usr/bin/python3"
        echo ""
        echo "  # Run against remote hosts:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i inventory/production/hosts.yml"
        echo ""
        echo "  # Run against remote hosts with sudo password:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i inventory/production/hosts.yml --ask-become-pass"
        echo ""
        echo "  # Run against manually specified host:"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i <host>, -u <user> -e target_user=<user>"
        echo ""
        echo "  # Dry run (check mode):"
        echo "  ansible-playbook playbooks/${playbook_name}.yml -i inventory/production/hosts.yml --check --diff"
        echo ""
        echo "  # Using just:"
        echo "  just run ${playbook_name}"
        echo "  just check ${playbook_name}"
        echo ""
        ;;
    6|*)
        echo "Cancelled."
        exit 0
        ;;
esac
