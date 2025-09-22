{ config, lib, pkgs, networkInterface ? "eth0", ... }:
let
  nodeIp = (lib.head config.networking.interfaces.${networkInterface}.ipv4.addresses).address;
in
{
  # nixpkgs.config.permittedInsecurePackages = [
  #   "k3s-1.30.14+k3s1"
  # ];

  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.k3s_1_33;
    tokenFile = "/run/agenix/k3s-token";
    serverAddr = "https://192.168.2.2:6443";
    clusterInit = false;
    extraFlags = "--flannel-iface=${networkInterface} --node-ip=${nodeIp} --node-taint node-role.kubernetes.io/master=true:NoSchedule --tls-san 192.168.2.2 --disable servicelb --disable traefik";
    extraKubeletConfig = {
      seccompDefault = true;
    };
    gracefulNodeShutdown.enable = true;
    
    manifests = {
      kube-vip-rbac = {
        source = pkgs.writeText "kube-vip-rbac.yaml" ''
          apiVersion: v1
          kind: ServiceAccount
          metadata:
            name: kube-vip
            namespace: kube-system
          ---
          apiVersion: rbac.authorization.k8s.io/v1
          kind: ClusterRole
          metadata:
            annotations:
              rbac.authorization.kubernetes.io/autoupdate: "true"
            name: system:kube-vip-role
          rules:
            - apiGroups: [""]
              resources: ["services/status"]
              verbs: ["update"]
            - apiGroups: [""]
              resources: ["services", "endpoints"]
              verbs: ["list","get","watch", "update"]
            - apiGroups: [""]
              resources: ["nodes"]
              verbs: ["list","get","watch", "update", "patch"]
            - apiGroups: ["coordination.k8s.io"]
              resources: ["leases"]
              verbs: ["list", "get", "watch", "update", "create"]
            - apiGroups: ["discovery.k8s.io"]
              resources: ["endpointslices"]
              verbs: ["list","get","watch", "update"]
          ---
          apiVersion: rbac.authorization.k8s.io/v1
          kind: ClusterRoleBinding
          metadata:
            name: system:kube-vip-binding
          roleRef:
            apiGroup: rbac.authorization.k8s.io
            kind: ClusterRole
            name: system:kube-vip-role
          subjects:
          - kind: ServiceAccount
            name: kube-vip
            namespace: kube-system
        '';
      };
      kube-vip-ds = {
        source = pkgs.writeText "kube-vip-ds.yaml" ''
          apiVersion: apps/v1
          kind: DaemonSet
          metadata:
            name: kube-vip-ds
            namespace: kube-system
          spec:
            selector:
              matchLabels:
                name: kube-vip-ds
            template:
              metadata:
                labels:
                  name: kube-vip-ds
              spec:
                affinity:
                  nodeAffinity:
                    requiredDuringSchedulingIgnoredDuringExecution:
                      nodeSelectorTerms:
                      - matchExpressions:
                        - key: node-role.kubernetes.io/master
                          operator: Exists
                      - matchExpressions:
                        - key: node-role.kubernetes.io/control-plane
                          operator: Exists
                containers:
                - args:
                  - manager
                  env:
                  - name: vip_arp
                    value: "true"
                  - name: port
                    value: "6443"
                  - name: vip_cidr
                    value: "32"
                  - name: cp_enable
                    value: "true"
                  - name: cp_namespace
                    value: kube-system
                  - name: vip_ddns
                    value: "false"
                  - name: svc_enable
                    value: "false"
                  - name: vip_leaderelection
                    value: "true"
                  - name: vip_leaseduration
                    value: "15"
                  - name: vip_renewdeadline
                    value: "10"
                  - name: vip_retryperiod
                    value: "2"
                  - name: address
                    value: "192.168.2.2"
                  image: ghcr.io/kube-vip/kube-vip:v0.8.7
                  imagePullPolicy: Always
                  name: kube-vip
                  resources: {}
                  securityContext:
                    capabilities:
                      add:
                      - NET_ADMIN
                      - NET_RAW
                      - SYS_TIME
                hostNetwork: true
                serviceAccountName: kube-vip
                tolerations:
                - effect: NoSchedule
                  operator: Exists
                - effect: NoExecute
                  operator: Exists
            updateStrategy: {}
        '';
      };
    };
  };

  virtualisation.containerd.enable = true;

  # environment.systemPackages = with pkgs; [ kubectl nfs-utils openiscsi jq dig gperftools ];
  #
  # services.openiscsi = {
  #   enable = true;
  #   name = "${config.networking.hostName}-initiatorhost";
  # };

  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];

  # boot.supportedFilesystems = [ "nfs" ];
  # services.rpcbind.enable = true;
}
