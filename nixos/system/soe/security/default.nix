{
  imports = [
    ./polkit
  ];

  security.sudo.configFile = ''
    %wheel  ALL=(ALL) NOPASSWD: ALL
  '';
}
