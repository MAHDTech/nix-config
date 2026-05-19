{ pkgs, ... }:
let
  username = "look_at_me_im_devops";
in
{
  users.users.${username} = {
    name = username;
    uid = 9999;
    isNormalUser = true;
    createHome = true;
    home = "/home/${username}";
    shell = pkgs.bashInteractive;
    group = username;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$0fQUL.dlpw4kaVRc$/cbRiuWeR5Pu9yc7uvF2sktWtGOtTjtXviU.mAtWZlOwURJ0Ld1Ccxo5K9yiQ7LqPMU3NCcGGrk3Q7jmiFgS21"; # spellchecker:disable-line

    # SOPS
    #hashedPasswordFile = config.sops.secrets.mahdtech.path;

    extraGroups = [
      username
      "adbusers"
      "audio"
      "disk"
      "docker"
      "flatpak"
      "nixos"
      "pipewire"
      "plugdev"
      "rtkit"
      "trezord"
      "users"
      "video"
      "vmware"
      "wheel"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
    ];
  };

  users.groups = {
    ${username} = {
      name = username;
      gid = 9999;
    };
  };
}
