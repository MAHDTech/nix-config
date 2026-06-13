{
  imports = [
    #./apparmor # TODO: Re-enable once tested on Zenbook.
    ./lsm
    ./pki
    ./polkit
  ];

  security.sudo.extraRules = [
    {
      groups = [ "nixos-admins" ];
      commands = [
        {
          command = "ALL";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
      ];
    }
  ];

}
