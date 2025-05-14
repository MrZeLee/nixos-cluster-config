{ pkgs, lib, ... }: {
  system.stateVersion = "24.05";

  zramSwap.enable = true;
  zramSwap.memoryPercent = 150;
}

