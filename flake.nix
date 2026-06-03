{
  description = "NixOS and Home Manager configuration";

  nixConfig = {
    extra-substituters = ''
      https://cache.nixos.org
      https://cosmic.cachix.org/
      https://devenv.cachix.org
      https://hyprland.cachix.org/
      https://mahdtech.cachix.org
      https://salt-labs.cachix.org
    '';
    extra-trusted-public-keys = "
      cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=
      devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
      hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=
      mahdtech.cachix.org-1:LtqGFUwyvUqRrl+LijURnBwkwQLwRO52dbDfrYkjWTg=
      salt-labs.cachix.org-1:9lBlhm9rPAHrb1GXnclFomAHsnj3kV+4DyJspy/nQlw=
    ";
    warn-dirty = true;
  };

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=release-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    systems.url = "github:nix-systems/default";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flatpaks.url = "github:in-a-dil-emma/declarative-flatpak/latest";
    stylix.url = "github:nix-community/stylix?ref=release-26.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv/main";
    impermanence.url = "github:nix-community/impermanence/master";
    crane.url = "github:ipetkov/crane";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opnix = {
      url = "github:brizzbuzz/opnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      lib = inputs.nixpkgs.lib;
      mylib = import ./lib { inherit lib inputs; };
      hosts = import ./nixos/hosts { inherit mylib inputs lib; };

      forEachSystem = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Installer configurations generated dynamically
      installerConfigs = builtins.listToAttrs (
        map (host: {
          name = "installer-${lib.toLower host.name}";
          value = mylib.mkInstaller {
            inherit (host) system;
            module = ./nixos/hosts/${lib.toLower host.name}/installer.nix;
          };
        }) hosts.list
      );
    in
    {
      nixosConfigurations = hosts.configs // installerConfigs;

      homeConfigurations = forEachSystem (system: {
        ${mylib.globalUsername} = mylib.mkHome { inherit system; };
      });

      packages = forEachSystem (
        system:
        {
          devenv-up =
            if system == builtins.currentSystem then
              self.devShells.${system}.default.config.procfileScript
            else
              inputs.nixpkgs.legacyPackages.${system}.hello;
        }
        // builtins.listToAttrs (
          map (host: {
            name = "installer-${lib.toLower host.name}";
            value = self.nixosConfigurations."installer-${lib.toLower host.name}".config.system.build.image;
          }) hosts.list
        )
      );

      devShells = forEachSystem (system: {
        default =
          if system == builtins.currentSystem then
            inputs.devenv.lib.mkShell {
              inherit inputs;
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              modules = [
                {
                  devenv.root =
                    let
                      pwd = builtins.getEnv "PWD";
                    in
                    if pwd != "" then pwd else toString ./.;
                }
                (import ./devenv/dotfiles.nix)
              ];
            }
          else
            inputs.nixpkgs.legacyPackages.${system}.mkShell {
              name = "dotfiles-cross-shell";
            };
      });
    };
}
