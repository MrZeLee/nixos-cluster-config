#!/usr/bin/env bash

set -euo pipefail

HOSTS_DIR="../hosts"
TMP_SYSTEM_KEYS=()
SECRETS_FILE_TEMPLATE="secrets.nix.template"
SECRETS_FILE="secrets.nix"
TMP_FILE="$(mktemp)"

# Extract the static head (everything before 'systems = [...]') from the template
HEAD_SECTION=$(awk '!/^ *systems *= *\[/ {print}' "$SECRETS_FILE_TEMPLATE" | sed '/^in/,$d')

# Extract the tail (everything from the first "in" block)
TAIL_SECTION=$(awk '/^in/ {found=1} found' "$SECRETS_FILE_TEMPLATE")

# Begin writing to the new temp file
echo "$HEAD_SECTION" > "$TMP_FILE"

# Now generate system host keys
for dir in "$HOSTS_DIR"/*; do
  host=$(basename "$dir")
  config="$dir/configuration.nix"

  if [[ ! -f "$config" ]]; then
    echo "Skipping $host: no configuration.nix"
    continue
  fi

  ip=$(grep 'address =' "$config" | head -n1 | sed -E 's/.*address = "(.*)";/\1/')
  if [[ -z "$ip" ]]; then
    echo "Skipping $host: no IP address found"
    continue
  fi

  echo "Fetching SSH host key for $host ($ip)..."

  key=$(ssh-keyscan -t ed25519 "$ip" 2>/dev/null | awk "/^$ip/ { print \$2 \" \" \$3 }")
  if [[ -z "$key" ]]; then
    echo "Warning: could not get key for $host ($ip)"
    continue
  fi

  varname="${host}"
  TMP_SYSTEM_KEYS+=("$varname")
  echo "  $varname = \"$key\";" >> "$TMP_FILE"
done

# Append the systems list
echo "" >> "$TMP_FILE"
echo "  systems = [" >> "$TMP_FILE"
for key in "${TMP_SYSTEM_KEYS[@]}"; do
  echo "    $key" >> "$TMP_FILE"
done
echo "  ];" >> "$TMP_FILE"

# Append preserved secret declaration
echo "$TAIL_SECTION" >> "$TMP_FILE"

# Finalize
mv "$TMP_FILE" "$SECRETS_FILE"
echo "✅ $SECRETS_FILE updated using $SECRETS_FILE_TEMPLATE"

