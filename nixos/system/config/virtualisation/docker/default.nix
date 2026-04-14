{
  pkgs,
  lib,
  ...
}:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    docker
    docker-ls
    docker-gc
    docker-client
    docker-buildx
  ];

  virtualisation = {
    oci-containers = {
      backend = "docker";
    };

    docker = {
      enable = true;

      package = pkgs.docker;
      enableOnBoot = true;
      storageDriver = lib.mkDefault "overlay2";
      logDriver = "journald";

      extraOptions = ''
        --iptables=false
      '';

      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };

      rootless = {
        enable = true;

        setSocketVariable = true;
      };
    };

    podman = {
      enable = false;

      # Create a 'docker' alias for podman
      dockerCompat = true;
    };
  };
}
