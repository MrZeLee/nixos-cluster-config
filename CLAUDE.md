# nixos-cluster-config

Declarative NixOS configuration for a hybrid K3s cluster (Nix flakes). This repo
manages the **operating systems**; cluster **applications** live in a separate
repo (`cluster`, Rancher Fleet GitOps, numbered bundles `01`–`17`).

## Layout

- `flake.nix` — entry point. `hosts` attrset maps each hostname → `{ system,
  format }`. `mkHost`/`mkImage` build NixOS configs and SD/USB installer images.
- `hosts/<name>/configuration.nix` — per-host config (static IP, role, hardware).
- `hardware/` — generated hardware profiles.
- `modules/*.nix` — reusable building blocks composed by hosts (see below).
- `secrets/` — agenix-encrypted secrets (`*.age`). `secrets.nix` declares them;
  `secrets/update-public-keys.sh` re-keys after host key changes.
- `terraform/` — Hetzner Cloud VM + Cloudflare DNS for `mourahouse.com`.
- `scripts/update-nodes.sh` — remote-deploy helper (see Deploy below).
- `docs/infrastructure/` — Beamer presentation documenting the infra.

## Hosts & roles

11 hosts. aarch64 = Raspberry Pi, x86_64 = mini PCs / cloud.

- `raspb0`–`raspb5` (aarch64): K3s **control-plane servers**. `raspb0` also
  initializes the cluster and runs MetalLB; built via `nixos-raspberrypi`.
- `raspb6`, `minipc` (aarch64/x86_64): K3s **agents**.
- `server` (x86_64): K3s agent + **Tailscale exit node** / subnet router.
- `n5pro` (x86_64): K3s agent + **ZFS storage node** for Longhorn.
- `headscale` (x86_64): **Hetzner Cloud VM**. Public IPv4 ingress
  (nginx SNI L4 → Traefik over WireGuard) + self-hosted Headscale control plane.

`raspb0` is special-cased in `mkHost` (uses `nixos-raspberrypi.lib.nixosSystem`).

## Conventions

- Format with **nixfmt-rfc-style**. Lint with **deadnix** and **statix**. These
  run as pre-commit hooks (`git-hooks.nix`) and as `nix flake check`.
- Per-host static IP lives as `address = "x.x.x.x";` in `configuration.nix`
  (the deploy script greps this). `headscale`'s IP comes from terraform output.
- Secrets are **always** agenix `.age` files — never commit plaintext secrets.
  Add a new secret in `secrets.nix` and encrypt with agenix.
- Shared behavior goes in a `modules/*.nix`; per-host specifics in the host file.

## Common commands

```bash
nix flake check                       # run nixfmt/deadnix/statix checks
nix fmt                               # (or rely on pre-commit) format
nix build .#packages.<system>.sd-image-<host>   # build an installer image

# Deploy (build on the target, remote sudo). fzf-select hosts if none given:
./scripts/update-nodes.sh --dry-run            # preview
./scripts/update-nodes.sh --switch raspb0      # one host
./scripts/update-nodes.sh --boot --parallel    # all hosts, on next boot

# Power off k3s nodes gracefully, in a safe order (agents/storage → servers →
# etcd-init last). fzf-select hosts if none given. --drain (local kubectl) only
# for partial shutdowns; plain run relies on gracefulNodeShutdown:
./scripts/shutdown-nodes.sh --dry-run          # preview the shutdown order
./scripts/shutdown-nodes.sh                    # whole cluster, ordered poweroff
./scripts/shutdown-nodes.sh --drain raspb6 n5pro  # subset: drain then off
```

`./scripts/update-nodes.sh [--dry-run] [--boot|--switch|--test] [--parallel] [host…]`

`./scripts/shutdown-nodes.sh [--drain] [--dry-run] [-y|--yes] [host…]`

## Gotchas

- **n5pro ZFS is manually unlocked.** The pool `tank` (RAIDZ1, encrypted) is not
  auto-imported/unlocked at boot — it needs `zpool import tank` + `zfs load-key
  tank`. Longhorn storage = zvol `tank/longhorn-block` → ext4 → `/mnt/longhorn-hdd-ext4`.
- **Overlapping subnet routers:** both a Tailscale operator and the Headscale
  router advertise `192.168.1.0/24`. Be deliberate when touching mesh routing.
- The Headscale tailnet domain is stored in the `headscale-domain.age` secret.
- `raspb0` boot path differs from the other Pis (nixos-raspberrypi flake).
- Pin issues (e.g. `k3s_1_33` missing): `nix flake update` or fall back to
  `pkgs.k3s` in the module.

## Working agreements

- This repo configures the OS only; if a task is about a running app/workload,
  it likely belongs in the `cluster` (Fleet) repo, not here.
- Make surgical changes that match existing module style; don't refactor
  unrelated Nix. Prefer `nix flake check` before declaring a change done.