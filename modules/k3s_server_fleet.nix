{ config, lib, pkgs, ... }:

{
  # Install Fleet using Helm chart
  services.k3s.autoDeployCharts = {
    fleet = {
      enable = true;
      name = "fleet";
      version = "0.9.4";
      repo = "https://rancher.github.io/fleet-helm-charts/";
      targetNamespace = "cattle-fleet-system";
      createNamespace = true;
      hash = "sha256-o18E3O1kHt+lY6Voww5sEoP/hlX71w+SUCP/GunIrr0=";
      values = {
        # Fleet configuration values
        gitops = {
          enabled = true;
        };
      };
    };
  };

  # Deploy GitRepo manifest after Fleet is installed
  services.k3s.manifests = {
    fleet-github-secret = {
      source = pkgs.runCommand "fleet-github-secret.yaml" {} ''
        cat > $out << 'EOF'
        apiVersion: v1
        kind: Secret
        metadata:
          name: basic-auth-secret
          namespace: fleet-local
        type: kubernetes.io/basic-auth
        stringData:
          username: MrZeLee
          password: "$(cat ${config.age.secrets.github-token.path})"
        EOF
      '';
    };
    
    fleet-gitrepo = {
      source = pkgs.writeText "fleet-gitrepo.yaml" ''
        apiVersion: fleet.cattle.io/v1alpha1
        kind: GitRepo
        metadata:
          name: Cluster-Tese
          namespace: fleet-local
        spec:
          repo: https://github.com/MrZeLee/cluster-tese
          branch: main
          paths:
          - .
          pollingInterval: 30s
          clientSecretName: basic-auth-secret
      '';
    };
  };
}
