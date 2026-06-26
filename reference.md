```
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: {
    # 1. Define your reusable profiles here
    nixosModules = {
      base = ./modules/base.nix;
      nas-services = ./modules/profiles/nas.nix;
      gaming-hardware = ./modules/hardware/amd.nix;
    };

    # 2. Define your individual hosts by pulling from the list above
    nixosConfigurations = {
      # A low-power ARM home server
      backup-pi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./hosts/backup-pi/hardware.nix
          self.nixosModules.base
        ];
      };

      # A beefy x86 NAS
      main-nas = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/main-nas/hardware.nix
          self.nixosModules.base
          self.nixosModules.nas-services
        ];
      };
    };
  };
}
```