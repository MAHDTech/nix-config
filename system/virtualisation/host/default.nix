{ inputs, config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  virtualisation = {

    vmware = {

      host = {

        enable = true;

        package = pkgs.vmware-workstation;

        extraPackages = with pkgs; [

          #ntfs3g

        ];

        extraConfig = ''

          # Allow unsupported device's OpenGL and Vulkan acceleration for guest vGPU
          mks.gl.allowUnsupportedDrivers = "TRUE"
          mks.vk.allowUnsupportedDevices = "TRUE"

        '';

      };

    };

  };

}