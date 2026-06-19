#!/usr/bin/env bash
set -euo pipefail

# Write a temporary NixOS module that adds a first-boot service.
# The service clones the repo, generates the hardware config for this
# machine, and applies the full headscale flake.
cat > /tmp/bootstrap.nix << 'NIXEOF'
{ pkgs, ... }: {
  users.users.mrzelee = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxGPJr0yZ9d+SOYqmEBP2GPejrfbAc45Ijsvk3PWYEP mrzelee404@gmail.com"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  systemd.services.apply-headscale = {
    description = "Apply headscale NixOS config from GitHub";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f /etc/.headscale-config-applied ]; then
        ${pkgs.git}/bin/git clone https://github.com/MrZeLee/nixos-cluster-config /tmp/cluster-config
        nixos-generate-config --show-hardware-config > /tmp/cluster-config/hardware/headscale.nix
        nixos-rebuild switch --flake /tmp/cluster-config#headscale
        touch /etc/.headscale-config-applied
      fi
    '';
  };
}
NIXEOF

# nixos-infect converts the running Ubuntu to NixOS, then reboots.
# NIXOS_IMPORT injects our bootstrap module into the initial NixOS config.
curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  PROVIDER=hetznercloud \
  NIX_CHANNEL=nixos-25.05 \
  NIXOS_IMPORT=/tmp/bootstrap.nix \
  bash 2>&1 | tee /tmp/infect.log