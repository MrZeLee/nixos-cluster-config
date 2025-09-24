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
      hash = "sha256-CRbUL/FRB5cYO+U8g4m2PKsFRVCHdGFOvijB9wpQmok=";
    };

    fleet = {
      enable = true;
      name = "fleet";
      version = "0.13.2";
      repo = "https://rancher.github.io/fleet-helm-charts/";
      targetNamespace = "cattle-fleet-system";
      createNamespace = true;
      dependsOn = [ "fleet-crd" ];
      hash = "sha256-geFseQCamuv75aeYfYgkWDDE1RY/oi8eTDP60FFcvHY=";
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
