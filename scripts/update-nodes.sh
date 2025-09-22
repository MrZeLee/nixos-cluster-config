#!/usr/bin/env bash
set -euo pipefail
HOSTS_DIR="../hosts"
ACTION="switch"  # Default action
DRY_RUN=false
PARALLEL=false
SSH_USER="mrzelee"

# Define SSH host overrides
declare -A SSH_OVERRIDES=(
    ["node1"]="10.0.0.100"
    ["node2"]="vpn.node2.internal"
)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --boot|--switch|--test)
            ACTION="${1#--}"
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --host)
            SPECIFIC_HOST="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--boot|--switch|--test] [--parallel] [--host hostname]"
            exit 1
            ;;
    esac
done

update_node() {
    local hostname=$1
    local ssh_target=$2
    
    echo "Updating $hostname at $ssh_target..."
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would run: ssh $SSH_USER@$ssh_target to rebuild"
    else
        # Copy the flake to the remote host
        echo "Copying flake to $hostname..."
        if ! ssh $SSH_USER@$ssh_target "mkdir -p /tmp/nixos-config"; then
            echo "❌ Failed to create directory on $hostname"
            return 1
        fi
        
        # Use rsync with exclusions for efficiency
        if ! rsync -av --delete \
            --exclude='.git' \
            --exclude='result' \
            --exclude='result-*' \
            --exclude='.direnv' \
            ../ $SSH_USER@$ssh_target:/tmp/nixos-config/; then
            echo "❌ Failed to copy files to $hostname"
            return 1
        fi
        
        # Run rebuild on the remote host
        echo "Running nixos-rebuild on $hostname..."
        if ssh $SSH_USER@$ssh_target "cd /tmp/nixos-config && sudo nixos-rebuild $ACTION --flake .#$hostname --show-trace"; then
            echo "✅ Successfully updated $hostname"
        else
            echo "❌ Failed to update $hostname"
            return 1
        fi
        
        # Clean up (always try to clean up, even on failure)
        ssh $SSH_USER@$ssh_target "rm -rf /tmp/nixos-config" || true
    fi
}

# Collect nodes to update
declare -a NODES_TO_UPDATE=()

for dir in "$HOSTS_DIR"/*; do
    if [[ ! -d "$dir" ]]; then
        continue
    fi
    
    hostname=$(basename "$dir")
    config="$dir/configuration.nix"
    
    # Skip if specific host requested and this isn't it
    if [[ -n "${SPECIFIC_HOST:-}" && "$hostname" != "$SPECIFIC_HOST" ]]; then
        continue
    fi
    
    if [[ ! -f "$config" ]]; then
        echo "Skipping $hostname: no configuration.nix"
        continue
    fi
    
    # Determine SSH target
    if [[ -v SSH_OVERRIDES["$hostname"] ]]; then
        ssh_target="${SSH_OVERRIDES[$hostname]}"
    else
        ip=$(grep 'address =' "$config" | head -n1 | sed -E 's/.*address = "(.*)";/\1/')
        if [[ -z "$ip" ]]; then
            echo "Skipping $hostname: no IP address found"
            continue
        fi
        ssh_target="$ip"
    fi
    
    NODES_TO_UPDATE+=("$hostname:$ssh_target")
done

# Check if any nodes to update
if [[ ${#NODES_TO_UPDATE[@]} -eq 0 ]]; then
    echo "No nodes found to update"
    exit 0
fi

# Update nodes
if [[ "$PARALLEL" == true ]]; then
    echo "Updating ${#NODES_TO_UPDATE[@]} nodes in parallel..."
    for node_info in "${NODES_TO_UPDATE[@]}"; do
        IFS=':' read -r hostname ssh_target <<< "$node_info"
        update_node "$hostname" "$ssh_target" &
    done
    wait
    echo "All updates completed."
else
    echo "Updating ${#NODES_TO_UPDATE[@]} nodes sequentially..."
    for node_info in "${NODES_TO_UPDATE[@]}"; do
        IFS=':' read -r hostname ssh_target <<< "$node_info"
        update_node "$hostname" "$ssh_target"
    done
fi
