{
  imports = [
    ./polkit
  ];

  security.sudo.configFile = ''
    %nixos-admins  ALL=(ALL) NOPASSWD: /usr/bin/nixos-rebuild, /run/current-system/sw/bin/nixos-rebuild

    %wheel  ALL=(ALL) NOPASSWD: ALL
    %wheel  ALL=(ALL:ALL) NOPASSWD: SETENV: ALL
  '';

}
