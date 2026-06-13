{
  imports = [
    ./apparmor
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
