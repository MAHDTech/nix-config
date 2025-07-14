{
  imports = [
    ./polkit
  ];

  security.sudo.configFile = ''
    %nixos-admins  ALL=(ALL:ALL) NOPASSWD: SETENV: ALL
  '';

}
