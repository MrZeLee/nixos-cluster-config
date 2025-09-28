{pkgs, lib, ...}: {
  programs.ssh.extraConfig = ''
    Host eu.nixbuild.net
    PubkeyAcceptedKeyTypes ssh-ed25519
    ServerAliveInterval 60
    IPQoS throughput
    IdentityFile ~/.ssh/nixbuild
  '';
  programs.ssh.knownHosts = {
    nixbuild = {
      hostNames = [ "eu.nixbuild.net" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
    };
  };

  nix.settings = {
    trusted-users = [ "mrzelee" ];
    builders-use-substitutes = true;
    experimental-features = ["nix-command" "flakes"];
  };

  nix = {
    distributedBuilds = true;
    buildMachines = [
      { hostName = "eu.nixbuild.net";
        system = "aarch64-linux";
        sshUser = "root";
        sshKey = "/home/mrzelee/.ssh/nixbuild";
        maxJobs = 100;
        supportedFeatures = [ "benchmark" "big-parallel"];
      }
    ];
  };
}
