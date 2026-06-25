#!/usr/bin/env bash
# Gracefully power off selected k3s nodes in an order that keeps the cluster healthy.
#
# Both the server and agent modules set `services.k3s.gracefulNodeShutdown.enable`,
# so a plain `systemctl poweroff` already makes kubelet cordon the node and
# terminate its pods within their grace period before the machine goes down.
# This script adds the two things that aren't automatic:
#
#   1. Safe ORDERING. Selected hosts are powered off in tiers, regardless of the
#      order you pick them in:
#        compute agents  ->  storage agents (server, n5pro)
#                        ->  non-init servers (raspb2-5)
#                        ->  etcd-init servers (raspb0, raspb1, LAST)
#      This keeps Longhorn volumes backed and etcd quorum alive as long as possible.
#
#   2. Optional DRAINING (--drain). For a *partial* shutdown where the rest of the
#      cluster keeps serving, this cordons + drains each node (via your LOCAL
#      kubectl) so workloads and Longhorn replicas relocate first. Pointless for a
#      full-cluster shutdown (nowhere to reschedule), so leave it off in that case.
#
# headscale is a Hetzner VM, not a k3s node — it is intentionally not selectable here.
#
# Usage: ./scripts/shutdown-nodes.sh [--drain] [--dry-run] [-y|--yes] [host ...]
#   No hosts given: fzf multi-select (falls back to "all k3s nodes").
set -uo pipefail

FLAKE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOSTS_DIR="${FLAKE_DIR}/hosts"
SSH_USER="mrzelee"
SSH=(ssh -o ConnectTimeout=8 -o BatchMode=yes)

DRAIN=false
DRY_RUN=false
ASSUME_YES=false

# Storage agents go last among agents so their volumes stay backed while other
# pods terminate. Hostnames per repo conventions (n5pro = ZFS, server = LUKS).
STORAGE_AGENTS=" server n5pro "

usage() {
  echo "Usage: $0 [--drain] [--dry-run] [-y|--yes] [host ...]"
  echo "  --drain    cordon + drain each node first (LOCAL kubectl) — for partial shutdowns"
  echo "  --dry-run  print the plan, touch nothing"
  echo "  -y|--yes   skip the confirmation prompt"
  echo "  No hosts:  fzf multi-select (all k3s nodes if fzf is absent)"
  exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --drain)   DRAIN=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -y|--yes)  ASSUME_YES=true; shift ;;
    --help|-h) usage 0 ;;
    --*)       echo "Unknown option: $1" >&2; usage ;;
    *)         break ;;
  esac
done

# --- Discover k3s nodes, their IP, role and shutdown tier --------------------
# Tier: 0 compute agent | 1 storage agent | 2 server | 3 etcd-init server.
declare -A HOST_IP=() HOST_ROLE=() HOST_TIER=()
for dir in "$HOSTS_DIR"/*/; do
  host=$(basename "$dir")
  config="${dir}configuration.nix"
  [[ -f "$config" ]] || continue

  if grep -q 'k3s_server' "$config"; then
    role="server"
    if grep -q 'clusterInit = lib.mkForce true' "$config"; then
      tier=3
    else
      tier=2
    fi
  elif grep -q 'k3s_agent.nix' "$config"; then
    role="agent"
    if [[ "$STORAGE_AGENTS" == *" $host "* ]]; then tier=1; else tier=0; fi
  else
    continue # not a k3s node (e.g. headscale)
  fi

  ip=$(grep 'address =' "$config" | head -n1 | sed -E 's/.*address = "(.*)";/\1/')
  [[ -n "$ip" ]] || continue
  HOST_IP[$host]="$ip"
  HOST_ROLE[$host]="$role"
  HOST_TIER[$host]="$tier"
done

# --- Select hosts ------------------------------------------------------------
if [[ $# -gt 0 ]]; then
  targets=("$@")
elif command -v fzf &>/dev/null; then
  mapfile -t targets < <(printf '%s\n' "${!HOST_IP[@]}" | sort |
    fzf --multi --prompt="Select nodes to power off (TAB to multi-select): " \
        --header="ENTER to confirm, ESC to abort")
  [[ ${#targets[@]} -gt 0 ]] || { echo "No hosts selected."; exit 0; }
else
  targets=("${!HOST_IP[@]}")
fi

for host in "${targets[@]}"; do
  if [[ ! -v HOST_IP[$host] ]]; then
    echo "Unknown / non-k3s host: ${host}" >&2
    echo "Selectable: $(printf '%s\n' "${!HOST_IP[@]}" | sort | tr '\n' ' ')" >&2
    exit 1
  fi
done

# Order the selection by shutdown tier (then name) into the canonical sequence.
mapfile -t ordered < <(
  for host in "${targets[@]}"; do printf '%s\t%s\n' "${HOST_TIER[$host]}" "$host"; done |
    sort -k1,1n -k2,2 | cut -f2 | awk '!seen[$0]++'
)

# --- Show the plan + confirm -------------------------------------------------
echo "Shutdown order (drain=${DRAIN}, dry-run=${DRY_RUN}):"
for host in "${ordered[@]}"; do
  case ${HOST_TIER[$host]} in
    0) label="agent" ;;
    1) label="agent/storage" ;;
    2) label="server" ;;
    3) label="server/etcd-init" ;;
  esac
  printf '  %-8s %-16s %s\n' "$host" "($label)" "${HOST_IP[$host]}"
done

if [[ "$DRY_RUN" == false && "$ASSUME_YES" == false ]]; then
  read -rp "Power off these ${#ordered[@]} node(s)? type 'yes': " ans
  [[ "$ans" == "yes" ]] || { echo "Aborted."; exit 0; }
fi

# --- Drain (local kubectl) then power off, host by host, in order ------------
if [[ "$DRAIN" == true ]] && ! command -v kubectl &>/dev/null; then
  echo "--drain given but kubectl not found locally." >&2
  exit 1
fi

rc=0
drained=()
for host in "${ordered[@]}"; do
  ip="${HOST_IP[$host]}"

  if [[ "$DRAIN" == true ]]; then
    echo "[${host}] cordon + drain (local kubectl)"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[${host}] DRY RUN: kubectl drain ${host} --ignore-daemonsets --delete-emptydir-data --force --timeout=300s"
    elif kubectl drain "$host" --ignore-daemonsets --delete-emptydir-data \
           --force --timeout=300s 2>&1 | sed "s/^/[${host}] /"; then
      drained+=("$host")
    else
      echo "[${host}] drain FAILED — NOT powering off this node" >&2
      rc=1
      continue
    fi
  fi

  # Servers run embedded etcd. Stop k3s cleanly FIRST (bounded, SIGKILL fallback)
  # so etcd closes its DB, then power off. Otherwise the last surviving member
  # loses quorum, k3s never finishes (re)starting, and that stuck `start` job
  # blocks the shutdown transition — `poweroff` silently does nothing. Agents
  # don't run etcd, so gracefulNodeShutdown + a plain poweroff is enough.
  if [[ "${HOST_ROLE[$host]}" == "server" ]]; then
    poweroff_cmd='echo "stopping k3s (max 60s, then SIGKILL)…"; sudo systemctl stop k3s.service & sp=$!; for i in $(seq 1 60); do kill -0 $sp 2>/dev/null || break; sleep 1; done; if kill -0 $sp 2>/dev/null; then sudo systemctl kill -s SIGKILL k3s.service; wait $sp 2>/dev/null; fi; sync; sudo systemctl poweroff --no-block'
  else
    poweroff_cmd='sudo systemctl poweroff --no-block'
  fi

  echo "[${host}] poweroff -> ${ip}"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[${host}] DRY RUN: ssh ${SSH_USER}@${ip} ${poweroff_cmd}"
    continue
  fi

  # A dropped connection here means the host is going down — that's success.
  if timeout 100 "${SSH[@]}" "${SSH_USER}@${ip}" "$poweroff_cmd" 2>&1 |
       sed "s/^/[${host}] /"; then
    echo "[${host}] powering down"
  else
    echo "[${host}] connection dropped / non-zero — host is powering down or already off"
  fi
done

if [[ "$DRY_RUN" == false && ${#drained[@]} -gt 0 ]]; then
  echo
  echo "Drained nodes stay cordoned. After they reboot, re-enable scheduling with:"
  echo "  kubectl uncordon ${drained[*]}"
fi

exit "$rc"