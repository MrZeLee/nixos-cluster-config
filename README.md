# nixos-cluster-config

This repository manages the declarative configuration of a multi-node NixOS
cluster using [Nix Flakes](https://nixos.wiki/wiki/Flakes). The cluster includes
a mix of ARM and x86_64 devices and is designed to be reproducible, modular, and
secure.

## ✨ Features

- ✅ Modular configuration using `./modules/*.nix`
- ✅ Per-host declarative configuration in
  `./hosts/<hostname>/configuration.nix`
- ✅ Secrets managed securely via [agenix](https://github.com/ryantm/agenix)
- ✅ Kubernetes with [K3s](https://k3s.io/) configured on select nodes
- ✅ Compatible with Raspberry Pi 4/5, and x86_64 nodes
- ✅ Optional integration with remote builders (e.g. nixbuild.net)

