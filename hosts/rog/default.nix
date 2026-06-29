{ pkgs, config, lib, ... }:
{
  networking.hostName = "rog01";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.blacklistedKernelModules = [ "nouveau" ];

  hardware.graphics.enable = true;

  # Required to build and load the proprietary nvidia kernel module.
  # modesetting = Intel iGPU; nvidia = discrete GPU (Optimus laptop).
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  system.stateVersion = "26.05";
}
