{ mylib, inputs, ... }:
let
  inherit (mylib) mkHost;
in
{
  # Metadata for other flake outputs
  list = [
    {
      name = "JONS";
      system = "x86_64-linux";
    }
    {
      name = "ARC";
      system = "x86_64-linux";
    }
    {
      name = "ZENBOOK";
      system = "aarch64-linux";
    }
    {
      name = "ORION";
      system = "aarch64-linux";
    }
    {
      name = "BOOTYCALL";
      system = "aarch64-linux";
    }
  ];

  # Actual configurations
  configs = {
    JONS = mkHost {
      name = "JONS";
      system = "x86_64-linux";
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
      hostType = "laptop";
      extraModules = [
        inputs.disko.nixosModules.disko
        ./zenbook/hardware/disko-config.nix
      ];
    };

    ORION = mkHost {
      name = "ORION";
      system = "aarch64-linux";
      hostType = "server";
      extraModules = [
        inputs.disko.nixosModules.disko
        ./orion/hardware/disko-config.nix
      ];
    };

    BOOTYCALL = mkHost {
      name = "BOOTYCALL";
      system = "aarch64-linux";
      hostType = "server";
      enableHomeManager = false;
      extraModules = [
        # Disko is not strictly required if using manual Android partitioning partitions,
        # but we mount it natively in default.nix / hardware-configuration.nix.
      ];
    };
  };
}
