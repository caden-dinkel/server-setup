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

    nixosConfigurations.omen01 = nixpkgs.lib.nixosSystem {
      modules = [
        ./hosts/omen01/hardware-configuration.nix
        self.nixosModules.base
        ./hosts/omen01/default.nix
      ];
    };

    deploy.nodes.omen01 = {
        hostname = "192.168.1.232";
        profiles.system = {
            sshUser = "caden";
            interactiveSudo = true;
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.omen01;
            remoteBuild = true;
        };
    };
    checks =
  if builtins.currentSystem == "x86_64-linux" then
    deploy-rs.lib.x86_64-linux.deployChecks self.deploy
  else
    {};
  };
}

