{ config, pkgs, lib, name, nixos-raspberrypi, ... }:

let
  # Network interface for this host
  networkInterface = "eth0";
in
{
  imports = [
    ../../hardware/${name}.nix
    # ../../modules/pi5-os-check.nix
    ../../modules/base.nix
    ../../modules/builder.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/k3s_server.nix
    ../../secrets.nix
  ] ++ (with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
  ]);

  networking.hostName = name;

  # Pass network interface to modules
  _module.args.networkInterface = networkInterface;

  # Optional: if you want to override IP per-host
  networking.interfaces.${networkInterface}.ipv4.addresses = [{
    address = "192.168.2.100";
    prefixLength = 23;
  }];

  services.k3s = {
    clusterInit = lib.mkForce true;
    serverAddr = lib.mkForce "";
  };

  # Download and apply MetalLB manifests (only on cluster init node)
  systemd.services.metallb-setup = {
    description = "Download and apply MetalLB manifests and configuration";
    after = [ "k3s.service" ];
    wants = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "metallb-setup" ''
        set -euo pipefail
        
        KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
        KUBECTL="${pkgs.k3s}/bin/kubectl --kubeconfig $KUBECONFIG"
        
        # Wait for k3s to be ready
        echo "Waiting for k3s to be ready..."
        while ! $KUBECTL get nodes &>/dev/null; do
          sleep 5
        done
        
        # Download and apply MetalLB
        METALLB_VERSION="v0.14.4"
        MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/$METALLB_VERSION/config/manifests/metallb-native.yaml"
        
        echo "Downloading and applying MetalLB manifests..."
        ${pkgs.curl}/bin/curl -fsSL "$MANIFEST_URL" | $KUBECTL apply -f -
        
        # Apply MetalLB configuration
        echo "Applying MetalLB IP pool and L2Advertisement..."
        cat <<EOF | $KUBECTL apply -f -
        apiVersion: metallb.io/v1beta1
        kind: IPAddressPool
        metadata:
          name: first-pool
          namespace: metallb-system
        spec:
          addresses:
          - 192.168.2.10-192.168.2.99
        ---
        apiVersion: metallb.io/v1beta1
        kind: L2Advertisement
        metadata:
          name: default
          namespace: metallb-system
        EOF
        
        echo "MetalLB setup completed successfully"
      '';
    };
  };

  # Set temporary password for user mrzelee
  users.users.mrzelee.initialPassword = "temporary123";
}
