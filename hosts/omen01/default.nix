{ pkgs, config, libs, ... }:
{
  networking.hostName = "omen01";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.blacklistedKernelModules = [ "nouveau" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  system.stateVersion = "26.05";
}
