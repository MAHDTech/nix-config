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

    # NOTE: To generate run;
    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$0fQUL.dlpw4kaVRc$/cbRiuWeR5Pu9yc7uvF2sktWtGOtTjtXviU.mAtWZlOwURJ0Ld1Ccxo5K9yiQ7LqPMU3NCcGGrk3Q7jmiFgS21"; # spellchecker:ignore-line

    # SOPS
    #hashedPasswordFile = config.sops.secrets.mahdtech.path;

    extraGroups = [
      username
      "adbusers"
      "audio"
      "dialout"
      "disk"
      "docker"
      "flatpak"
      "input"
      "networkmanager"
      "nixos"
      "nixos-admins"
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

      # Incus
      #"incus"            # incus pleb group.
      "incus-admin" # incus admins group.
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
    ];
  };

  users.groups = {
    ${username} = {
      name = username;
      gid = 1000;
    };
  };
}
