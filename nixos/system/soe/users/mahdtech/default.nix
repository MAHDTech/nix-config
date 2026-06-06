{ pkgs, ... }:
let
  username = "mahdtech";
in
{
  users.users.${username} = {
    name = username;
    uid = 1000;
    isNormalUser = true;
    createHome = true;
    home = "/home/${username}";
    shell = pkgs.bashInteractive;
    group = username;

    # Enable linger
    linger = true;

    # NOTE: To generate run;
    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$0fQUL.dlpw4kaVRc$/cbRiuWeR5Pu9yc7uvF2sktWtGOtTjtXviU.mAtWZlOwURJ0Ld1Ccxo5K9yiQ7LqPMU3NCcGGrk3Q7jmiFgS21"; # spellchecker:ignore-line

    extraGroups = [
      username
      "adbusers"
      "audio"
      "dialout"
      "disk"
      "docker"
      "flatpak"
      "input"
      "nixos"
      "nixos-admins"
      "onepassword-secrets"
      "pipewire"
      "plugdev"
      "rtkit"
      "trezord"
      "users"
      "video"
      "wheel"

      # VMware
      "vmware"

      # KVM/QEMU
      "kvm"
      "qemu"
      "libvirt"
      "libvirtd"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvQpgd14xx/ZZeIFzoa2ztmk0MNjHObmIbbnkxzCSvV mahdtech@local"
    ];
  };

  users.groups = {
    ${username} = {
      name = username;
      gid = 1000;
    };
  };

  systemd.services."home-manager-${username}" = {
    serviceConfig.SupplementaryGroups = [ "onepassword-secrets" ];
  };
}
