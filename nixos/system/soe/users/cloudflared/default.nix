{pkgs, ...}: let
  username = "cloudflared";
in {
  users.users.${username} = {
    name = username;
    uid = 1001;
    isNormalUser = false;
    isSystemUser = true;
    createHome = true;
    home = "/home/${username}";
    shell = pkgs.bashInteractive;
    group = username;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$0fQUL.dlpw4kaVRc$/cbRiuWeR5Pu9yc7uvF2sktWtGOtTjtXviU.mAtWZlOwURJ0Ld1Ccxo5K9yiQ7LqPMU3NCcGGrk3Q7jmiFgS21";

    # SOPS
    #hashedPasswordFile = config.sops.secrets.cloudflared.path;

    extraGroups = [
      username
    ];

    openssh.authorizedKeys.keys = [
    ];
  };

  users.groups = {
    ${username} = {
      name = username;
      gid = 1001;
    };
  };
}
