{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
  ];

  hardware = {
    pulseaudio.enable = false;
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    systemWide = true;
    socketActivation = true;

    audio = {enable = true;};

    wireplumber = {
      enable = true;
      package = pkgs.wireplumber;
    };

    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
  };
}
