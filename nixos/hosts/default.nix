{ mylib, inputs, ... }:
let
  inherit (mylib) mkHost;
in
{
  # Metadata for other flake outputs
  # buildSystem: the machine that compiles. When it differs from system,
  #              nixpkgs is configured for cross-compilation automatically.
  # nixConfig: host-specific Nix settings (e.g. maxJobs) forwarded into
  #            nix.settings and system.autoUpgrade.flags.
  list = [
    {
      name = "JONS";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixConfig = { };
    }
    {
      name = "ARC";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixConfig = { };
    }
    {
      name = "ZENBOOK";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux";
      nixConfig = {
        maxJobs = 2;
      };
    }
    {
      name = "ORION";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux";
      nixConfig = {
        maxJobs = 2;
      };
    }
    {
      name = "BOOTYCALL";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux";
      nixConfig = {
        maxJobs = 2;
      };
    }
    {
      name = "test-nixos";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
      nixConfig = { };
    }
  ];

  # Actual configurations
  configs = rec {
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
      nixConfig = {
        maxJobs = 2;
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
      nixConfig = {
        maxJobs = 2;
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
      nixConfig = {
        maxJobs = 2;
      };
      enableHomeManager = false;
      extraModules = [
        inputs.disko.nixosModules.disko
      ];
    };
  };
}
