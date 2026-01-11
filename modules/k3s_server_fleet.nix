{ config, lib, pkgs, ... }:

{
  # Install Fleet using Helm chart
  services.k3s.autoDeployCharts = {
    fleet-crd = {
      enable = true;
      name = "fleet-crd";
      version = "0.13.2";
      repo = "https://rancher.github.io/fleet-helm-charts/";
      targetNamespace = "cattle-fleet-system";
      createNamespace = true;
      hash = "sha256-xJedoH1NCWP0HnsjP6+tM4lrFov8uccvr49ZTb48Wnc=";
    };

    fleet = {
      enable = true;
      name = "fleet";
      version = "0.13.2";
      repo = "https://rancher.github.io/fleet-helm-charts/";
      targetNamespace = "cattle-fleet-system";
      createNamespace = true;
      hash = "sha256-ypho/zletI9GVcBQ95KU01Z4N2a9Cupr4a14zJ92c9c=";
      values = {
        # Fleet configuration values
        gitops = {
          enabled = true;
        };
      };
    };
  };

  # Create GitHub secret at runtime when agenix token is available
  systemd.services.fleet-github-secret = {
    description = "Create GitHub secret for Fleet from agenix";
    wantedBy = [ "multi-user.target" ];
    after = [ "k3s.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "create-fleet-github-secret" ''
        set -e
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        # Wait for k3s to be ready
        echo "Waiting for k3s to be ready..."
        until ${pkgs.k3s}/bin/kubectl get nodes >/dev/null 2>&1; do
          sleep 5
        done
        
        # Create fleet-local namespace
        ${pkgs.k3s}/bin/kubectl create namespace fleet-local --dry-run=client -o yaml | ${pkgs.k3s}/bin/kubectl apply -f -
        
        # Read token and create secret
        TOKEN=$(cat ${config.age.secrets.github-token.path})
        ${pkgs.k3s}/bin/kubectl create secret generic basic-auth-secret \
          --namespace=fleet-local \
          --from-literal=username=MrZeLee \
          --from-literal=password="$TOKEN" \
          --type=kubernetes.io/basic-auth \
          --dry-run=client -o yaml | ${pkgs.k3s}/bin/kubectl apply -f -
        
        echo "Fleet GitHub secret created successfully"
      '';
    };
  };

  # Deploy GitRepo manifest after Fleet is installed
  services.k3s.manifests = {
    fleet-gitrepo = {
      source = pkgs.writeText "fleet-gitrepo.yaml" ''
        apiVersion: fleet.cattle.io/v1alpha1
        kind: GitRepo
        metadata:
          name: cluster-tese
          namespace: fleet-local
        spec:
          repo: https://github.com/MrZeLee/cluster-tese
          branch: main
          # paths:
          # - .
          pollingInterval: 120s
          clientSecretName: basic-auth-secret
      '';
    };
  };
}
