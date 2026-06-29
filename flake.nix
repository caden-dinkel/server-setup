{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can change the word unstable to the latest number shown here: https://nixos.org/download
    # i.e. nixos-24.11
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = inputs@{ self, nixpkgs, deploy-rs, ... }: {
    nixosModules = {
      base = ./modules/base.nix;
    };

    nixosConfigurations.omen = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/omen/hardware-configuration.nix
        self.nixosModules.base
        ./hosts/omen/default.nix
      ];
    };

    nixosConfigurations.rog01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
            ./hosts/rog/hardware-configuration.nix
            ./hosts/rog/default.nix
            self.nixosModules.base
        ];
    };

    deploy.nodes.omen = {
        hostname = "192.168.1.232";
        profiles.system = {
            sshUser = "caden";
            interactiveSudo = true;
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.omen;
            remoteBuild = true;
        };
    };

    deploy.nodes.rog01 = {
        hostName = "192.168.1.182";
        profiles.system = {
            sshUser = "caden";
            interactiveSudo = true;
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.rog01;
            remoteBuild = true;
        };
    };
  };
}

