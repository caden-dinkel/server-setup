{ pkgs, ... }:

{
  networking.networkmanager.enable = true;

  users.users.caden = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      neovim
      pciutils
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeXz6ax83OTBxo7t1XURFFJRwnxyc5ieErtqupaux7M mac@cdink.dev"
    ];
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
  };

  services.openssh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;
}
