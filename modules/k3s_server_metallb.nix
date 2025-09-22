{ config, lib, pkgs, ... }:

{
  services.k3s.manifests = {
    metallb-namespace = {
      source = pkgs.writeText "metallb-namespace.yaml" ''
        apiVersion: v1
        kind: Namespace
        metadata:
          name: metallb-system
          labels:
            pod-security.kubernetes.io/enforce: privileged
            pod-security.kubernetes.io/audit: privileged
            pod-security.kubernetes.io/warn: privileged
      '';
    };
    
    metallb-config = {
      source = pkgs.writeText "metallb-config.yaml" ''
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
      '';
    };
  };
}