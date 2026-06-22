#!/usr/bin/env bash
# Unlock the encrypted storage on the cluster's storage nodes after a reboot.
#
#   server : LUKS2 on /dev/md0  -> /dev/mapper/longhorn-raid0 -> /mnt/longhorn-server-raid0
#   n5pro  : ZFS native-encrypted pool `tank` -> ext4 zvol     -> /mnt/longhorn-hdd-ext4
#
# Each host is checked first; any host that is already imported/opened AND mounted
# is skipped. You are only prompted for a password when something needs unlocking.
# The same password is tried on every host that needs it; on failure you are
# re-prompted per host (so different passphrases also work).
set -uo pipefail

SSH_USER="mrzelee"
SSH=(ssh -o ConnectTimeout=8 -o BatchMode=yes)

FLAKE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ip_of() {
  grep 'address =' "${FLAKE_DIR}/hosts/$1/configuration.nix" | head -n1 |
    sed -E 's/.*address = "(.*)";/\1/'
}
SERVER_IP="$(ip_of server)"
N5PRO_IP="$(ip_of n5pro)"

# --- "already unlocked?" checks (exit 0 = fully unlocked + mounted) ------------
server_ready() {
  "${SSH[@]}" "${SSH_USER}@${SERVER_IP}" \
    'sudo cryptsetup status longhorn-raid0 >/dev/null 2>&1 && mountpoint -q /mnt/longhorn-server-raid0'
}
n5pro_ready() {
  "${SSH[@]}" "${SSH_USER}@${N5PRO_IP}" '
    sudo zpool list tank >/dev/null 2>&1 \
      && [ "$(sudo zfs get -H -o value keystatus tank 2>/dev/null)" = available ] \
      && mountpoint -q /mnt/longhorn-hdd-ext4'
}

# --- unlock actions (return 0 on success) ------------------------------------
server_unlock() { # $1 = password
  if ! "${SSH[@]}" "${SSH_USER}@${SERVER_IP}" 'sudo cryptsetup status longhorn-raid0 >/dev/null 2>&1'; then
    printf '%s\n' "$1" | "${SSH[@]}" "${SSH_USER}@${SERVER_IP}" \
      'sudo cryptsetup luksOpen /dev/md0 longhorn-raid0' || return 1
  fi
  "${SSH[@]}" "${SSH_USER}@${SERVER_IP}" \
    'mountpoint -q /mnt/longhorn-server-raid0 || sudo mount /mnt/longhorn-server-raid0'
}
n5pro_unlock() { # $1 = password
  "${SSH[@]}" "${SSH_USER}@${N5PRO_IP}" 'sudo zpool list tank >/dev/null 2>&1 || sudo zpool import tank' || return 1
  if [ "$("${SSH[@]}" "${SSH_USER}@${N5PRO_IP}" 'sudo zfs get -H -o value keystatus tank 2>/dev/null')" != "available" ]; then
    printf '%s\n' "$1" | "${SSH[@]}" "${SSH_USER}@${N5PRO_IP}" 'sudo zfs load-key tank' || return 1
  fi
  "${SSH[@]}" "${SSH_USER}@${N5PRO_IP}" \
    'sudo zfs mount -a; mountpoint -q /mnt/longhorn-hdd-ext4 || sudo mount /mnt/longhorn-hdd-ext4'
}

# --- figure out which hosts need unlocking -----------------------------------
need=()
if server_ready; then echo "server : already unlocked — skipping"; else need+=("server"); fi
if n5pro_ready;  then echo "n5pro  : already unlocked — skipping"; else need+=("n5pro"); fi

if [ "${#need[@]}" -eq 0 ]; then
  echo "Both nodes already unlocked. Nothing to do."
  exit 0
fi

read -rsp "Encryption password: " PASS; echo

rc=0
for h in "${need[@]}"; do
  pass="$PASS"
  tries=0
  while :; do
    if "${h}_unlock" "$pass"; then
      echo "${h} : unlocked ✓"
      break
    fi
    tries=$((tries + 1))
    if [ "$tries" -ge 3 ]; then
      echo "${h} : FAILED after ${tries} attempts" >&2
      rc=1
      break
    fi
    read -rsp "${h} : wrong password or error, retry: " pass; echo
  done
done

exit "$rc"