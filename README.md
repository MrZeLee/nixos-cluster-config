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

## 🚀 Build and Flash Images

This repo exposes pre-configured SD/USB installer images for each host via flake
packages.

Prerequisites

- Nix with flakes enabled
- A Linux machine (or WSL) with `zstd`, `dd`, and `lsblk`

Build (examples)

- Raspberry Pi 4/5 host `raspb1` (aarch64):
  - `nix build .#packages.aarch64-linux.sd-image-raspb1`
- x86_64 host `server` (example):
  - `nix build .#packages.x86_64-linux.sd-image-server`

Result

- The build produces: `result/sd-image/<name>-sd-image-*.img.zst`

Optional: wipe/format device before flashing

- For these full-disk images, formatting is not required; `dd` overwrites the
  partition table.
- If you hit odd mount/partition issues, wipe existing signatures first:
  - Pick device: `export DEV=/dev/sdX` (or `/dev/mmcblk0`)
  - Unmount anything mounted: `sudo umount ${DEV}?* || true`
  - Wipe signatures: `sudo wipefs -a $DEV`
  - (Optional) Zero first MiBs:
    `sudo dd if=/dev/zero of=$DEV bs=1M count=10 conv=fsync`

Manual partition + format (only if NOT using the dd image)

- This is for manual installs; the dd image will overwrite this layout anyway.
- Create MBR with boot (FAT32) and root (ext4) partitions:
  - `sudo parted -s $DEV mklabel msdos \`
    `mkpart primary fat32 1MiB 256MiB set 1 boot on \`
    `mkpart primary ext4 256MiB 100%`
  - `sudo mkfs.vfat -F32 ${DEV}1`
  - `sudo mkfs.ext4 -F ${DEV}2`

Flash to SD/USB (Linux)

1. Identify your device: `lsblk` (e.g. `/dev/sdX` or `/dev/mmcblk0`)
2. Write the image (replace `/dev/sdX` accordingly):
   <!-- markdownlint-disable MD013 -->
   - `zstd -d -c result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress`
   <!-- markdownlint-enable MD013 -->
3. Flush buffers: `sync`

Boot & SSH

- Insert the card/USB, power on, wait 1–3 minutes on first boot.
- Networking is per-host. For `raspb1`, the static IP is `192.168.2.101/23` with
  gateway `192.168.2.1`.
- SSH user: `mrzelee` (SSH keys baked in; password login disabled)
- Connect: `ssh mrzelee@192.168.2.101`

## 📦 Mount SD/USB (after flashing)

Sometimes you may want to inspect or tweak files on the image (e.g. boot config)
before first boot.

Identify partitions

- `lsblk -f` (look for your device, e.g. `/dev/sdX` or `/dev/mmcblk0`)
- Expect two partitions: a small `vfat` (boot) and a larger `ext4` (root)

Create mount points

- `sudo mkdir -p /mnt/sd-boot /mnt/sd-root`

Mount (replace `sdX` with your device)

- For USB/SD as `/dev/sdX`:
  - Boot: `sudo mount /dev/sdX1 /mnt/sd-boot`
  - Root: `sudo mount /dev/sdX2 /mnt/sd-root`
- For microSD as `/dev/mmcblk0`:
  - Boot: `sudo mount /dev/mmcblk0p1 /mnt/sd-boot`
  - Root: `sudo mount /dev/mmcblk0p2 /mnt/sd-root`

If partitions don’t appear after flashing

- Refresh kernel view: `sudo partprobe /dev/sdX` (or reinsert the device)

When done

- `sudo umount /mnt/sd-boot /mnt/sd-root && sync`

Notes

- Ensure the static IP in `hosts/<hostname>/configuration.nix` fits your LAN
  before building.
- Image builds are powered by `nixos-generators` and use the repo’s pinned
  `nixpkgs`.
- If a package attribute is missing due to a pin (e.g., `k3s_1_33`), run
  `nix flake update` or adjust the module to fall back to `pkgs.k3s`.
