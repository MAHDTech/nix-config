{ mylib, inputs, ... }:
let
  inherit (mylib) mkHost;
  runnerNames = [
    "github-runner-01"
    "github-runner-02"
    "github-runner-03"
    "github-runner-04"
    "github-runner-05"
    "github-runner-06"
    "github-runner-07"
    "github-runner-08"
    "github-runner-09"
    "github-runner-10"
    "github-runner-11"
    "github-runner-12"
    "github-runner-13"
    "github-runner-14"
    "github-runner-15"
    "github-runner-16"
    "github-runner-17"
    "github-runner-18"
    "github-runner-19"
    "github-runner-20"
  ];
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
      name = "ARC";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixSettings = { };
    }
    {
      name = "ZENBOOK";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux";
      nixSettings = {
        max-jobs = 2;
      };
    }
    {
      name = "ORION";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux";
      nixSettings = {
        max-jobs = 2;
      };
    }
    {
      name = "BOOTYCALL";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux";
      nixSettings = {
        # Low-power 8-core Cortex-A53: build sequentially to avoid OOM.
        max-jobs = 1;
        cores = 4;
      };
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

      ARC = mkHost {
        name = "ARC";
        system = "x86_64-linux";
        buildSystem = "x86_64-linux";
        hostType = "desktop";
        extraModules = [
          inputs.disko.nixosModules.disko
          inputs.nixos-hardware.nixosModules.common-cpu-amd
          inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
          inputs.nixos-hardware.nixosModules.common-gpu-intel
          inputs.nixos-hardware.nixosModules.common-hidpi
          inputs.nixos-hardware.nixosModules.common-pc
          inputs.nixos-hardware.nixosModules.common-pc-ssd
        ];
      };

      ZENBOOK = mkHost {
        name = "ZENBOOK";
        system = "aarch64-linux";
        buildSystem = "aarch64-linux";
        hostType = "laptop";
        nixSettings = {
          max-jobs = 2;
        };
        extraModules = [
          inputs.disko.nixosModules.disko
          ./zenbook/hardware/disko-config.nix
        ];
      };

      ORION = mkHost {
        name = "ORION";
        system = "aarch64-linux";
        buildSystem = "aarch64-linux";
        hostType = "server";
        nixSettings = {
          max-jobs = 2;
        };
        extraModules = [
          inputs.disko.nixosModules.disko
          ./orion/hardware/disko-config.nix
        ];
      };

      BOOTYCALL = mkHost {
        name = "BOOTYCALL";
        system = "aarch64-linux";
        buildSystem = "aarch64-linux";
        hostType = "server";
        nixSettings = {
          # Low-power 8-core Cortex-A53: build sequentially to avoid OOM.
          max-jobs = 1;
          cores = 4;
        };
        enableHomeManager = false;
        extraModules = [
          inputs.disko.nixosModules.disko
        ];
      };
    };
}
