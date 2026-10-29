{ mylib, inputs, ... }:
let
  fleet = import ./fleet.nix;
  inherit (fleet) runnerNames;
  mkHost =
    args:
    mylib.mkHost (
      args
      // {
        extraModules =
          (args.extraModules or [ ])
          ++ inputs.nixpkgs.lib.optional (builtins.hasAttr args.name fleet.beszel.members) ./beszel-agent.nix;
      }
    );
in
{
  # Metadata for other flake outputs
  # buildSystem: the machine that compiles. When it differs from system,
  #              nixpkgs is configured for cross-compilation automatically.
  # nixSettings: host-specific Nix settings, keyed by real nix.settings names
  #              (e.g. max-jobs, cores). Passed through verbatim into
  #              nix.settings and, as --option flags, into
  #              system.autoUpgrade.flags. Any Nix setting works; unset keys
  #              keep the fleet default from nixos/system/soe/nix.
  list = [
    {
      name = "mirror";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixSettings = { };
    }
    {
      name = "hub";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixSettings = { };
    }
    {
      name = "s3";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixSettings = { };
    }
    {
      name = "nix-cache";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixSettings = { };
    }
    {
      name = "JONS";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixSettings = { };
    }
    {
      name = "test-nixos";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixSettings = { };
    }
  ]
  ++ map (name: {
    inherit name;
    system = "x86_64-linux";
    buildSystem = "x86_64-linux";
    nixSettings = { };
  }) runnerNames;

  # Actual configurations
  configs =
    inputs.nixpkgs.lib.genAttrs runnerNames (
      name:
      mkHost {
        inherit name;
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "server";
        enableHomeManager = false;
      }
    )
    // rec {
      mirror = mkHost {
        name = "mirror";
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "server";
        enableHomeManager = false;
      };
      hub = mkHost {
        name = "hub";
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "server";
        enableHomeManager = false;
      };
      s3 = mkHost {
        name = "s3";
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "server";
        enableHomeManager = false;
      };
      nix-cache = mkHost {
        name = "nix-cache";
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "server";
        enableHomeManager = false;
      };
      test-nixos = mkHost {
        name = "test-nixos";
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "server";
        enableHomeManager = false;
        extraModules = [
          inputs.disko.nixosModules.disko
        ];
      };
      TEST-NIXOS = test-nixos;

      JONS = mkHost {
        name = "JONS";
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "desktop";
        extraModules = [
          inputs.nixos-hardware.nixosModules.common-cpu-amd
          inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
          inputs.nixos-hardware.nixosModules.common-gpu-intel
          inputs.nixos-hardware.nixosModules.common-hidpi
          inputs.nixos-hardware.nixosModules.common-pc
          inputs.nixos-hardware.nixosModules.common-pc-ssd
        ];
      };
    };
}
