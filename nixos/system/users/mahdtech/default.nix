{pkgs, ...}: let
  username = "mahdtech";
in {
  users.users.${username} = {
    name = username;
    uid = 1000;
    isNormalUser = true;
    createHome = true;
    home = "/home/${username}";
    shell = pkgs.bash;
    group = username;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$0fQUL.dlpw4kaVRc$/cbRiuWeR5Pu9yc7uvF2sktWtGOtTjtXviU.mAtWZlOwURJ0Ld1Ccxo5K9yiQ7LqPMU3NCcGGrk3Q7jmiFgS21";

    # SOPS
    #passwordFile = config.sops.secrets.mahdtech.path;

    extraGroups = [
      username
      "audio"
      "disk"
      "docker"
      "flatpak"
      "networkmanager"
      "pipewire"
      "plugdev"
      "video"
      "vmware"
      "wheel"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
    ];
  };

  users.groups = {
    ${username} = {
      name = username;
      gid = 1000;
    };
  };
}
