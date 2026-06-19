#!/usr/bin/env bash
set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOSTS_DIR="${FLAKE_DIR}/hosts"
TERRAFORM_DIR="${FLAKE_DIR}/terraform"
SSH_USER="mrzelee"
ACTION="switch"
PARALLEL=false
DRY_RUN=false

# Discover host -> IP the same way update-public-keys.sh does
declare -A HOST_IP=()
for dir in "$HOSTS_DIR"/*/; do
  host=$(basename "$dir")
  config="${dir}configuration.nix"
  [[ -f "$config" ]] || continue

  if [[ "$host" == "headscale" ]]; then
    ip=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null || true)
  else
    ip=$(grep 'address =' "$config" | head -n1 | sed -E 's/.*address = "(.*)";/\1/')
  fi

  [[ -n "$ip" ]] && HOST_IP[$host]="$ip"
done

usage() {
  echo "Usage: $0 [--dry-run] [--boot|--switch|--test] [--parallel] [host ...]"
  echo "  No hosts specified: update all hosts"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)   DRY_RUN=true; shift ;;
    --parallel)  PARALLEL=true; shift ;;
    --boot|--switch|--test) ACTION="${1#--}"; shift ;;
    --help)      usage ;;
    --*)         echo "Unknown option: $1"; usage ;;
    *)           break ;;
  esac
done

# Remaining args are host names; default to all
if [[ $# -gt 0 ]]; then
  targets=("$@")
else
  targets=("${!HOST_IP[@]}")
fi

rebuild_host() {
  local host="$1"
  local ip="${HOST_IP[$host]}"
  local args=(
    --flake "${FLAKE_DIR}#${host}"
    --target-host "${SSH_USER}@${ip}"
    --use-remote-sudo
    --option always-allow-substitutes true
  )

  args+=(--build-host "${SSH_USER}@${ip}")

  echo "[${host}] rebuilding → ${ip}"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[${host}] DRY RUN: nixos-rebuild ${ACTION} ${args[*]}"
    return 0
  fi

  if nixos-rebuild "$ACTION" "${args[@]}" 2>&1 | sed "s/^/[${host}] /"; then
    echo "[${host}] done"
  else
    echo "[${host}] FAILED" >&2
    return 1
  fi
}

# Validate hosts
for host in "${targets[@]}"; do
  if [[ ! -v HOST_IP[$host] ]]; then
    echo "Unknown host: ${host}" >&2
    echo "Available: ${!HOST_IP[*]}" >&2
    exit 1
  fi
done

echo "Action: ${ACTION} | Hosts: ${targets[*]} | Parallel: ${PARALLEL}"

if [[ "$PARALLEL" == true ]]; then
  pids=()
  for host in "${targets[@]}"; do
    rebuild_host "$host" &
    pids+=($!)
  done

  failed=()
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      failed+=("${targets[$i]}")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "FAILED: ${failed[*]}" >&2
    exit 1
  fi
else
  for host in "${targets[@]}"; do
    rebuild_host "$host" || exit 1
  done
fi

echo "Done."