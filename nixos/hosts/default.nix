{ mylib, inputs, ... }:
let
  inherit (mylib) mkHost;
in
{
  # Metadata for other flake outputs
  # buildSystem: the machine that compiles. When it differs from system,
  #              nixpkgs is configured for cross-compilation automatically.
  #
  # Every host is currently native (buildSystem == system). Cross-compiling an
  # aarch64-linux host from x86_64 produces derivation hashes that do not exist
  # on cache.nixos.org, so it rebuilds the whole closure from source. A native
  # aarch64 build substitutes nearly all of it. Build aarch64 hosts on aarch64
  # hardware, or on x86_64 under binfmt emulation — both hash identically and
  # hit the cache. The cross path in lib/default.nix is kept as an escape hatch
  # for targets with no aarch64 builder available.
  list = [
    {
      name = "JONS";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux"; # native
    }
    {
      name = "ARC";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux"; # native
    }
    {
      name = "ZENBOOK";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux"; # native ARM64
    }
    {
      name = "ORION";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux"; # native ARM64
    }
    {
      name = "BOOTYCALL";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux"; # native ARM64 — build on ORION, or on x86_64 under binfmt
    }
    {
      name = "test-nixos";
      system = "x86_64-linux";
      buildSystem = "x86_64-linux";
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
      extraModules = [
        inputs.disko.nixosModules.disko
        ./orion/hardware/disko-config.nix
      ];
    };

    BOOTYCALL = mkHost {
      name = "BOOTYCALL";
      system = "aarch64-linux";
      buildSystem = "aarch64-linux"; # native ARM64
      hostType = "server";
      enableHomeManager = false;
      extraModules = [
        inputs.disko.nixosModules.disko
      ];
    };
  };
}
