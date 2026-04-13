{

  ##########################
  # NOTE:
  # - System groups are < 1000
  ##########################

  users.groups = {
    "nixos-admins" = {
      gid = 100000;
    };

    "plugdev" = {
      gid = 980;
    };

    "vmware" = {
      gid = 981;
    };

    "trezord" = {
      gid = 982;
    };

    "nixos" = {
      gid = 983;
    };

    "adbusers" = {
      gid = 984;
    };
  };
}
