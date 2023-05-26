{
  config,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  sound.enable = true;

  hardware.pulseaudio.enable = false;

  nixpkgs.config.pulseaudio = false;

  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  services.pipewire = {
    enable = true;

    systemWide = true;
    socketActivation = true;

    audio = {enable = true;};

    wireplumber = {
      enable = true;
      package = pkgs.wireplumber;
    };

    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;
  };
}
