{ pkgs, ... }:
{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    trim.enable = true;
  };

  environment.systemPackages = [ pkgs.zfs ];
}
