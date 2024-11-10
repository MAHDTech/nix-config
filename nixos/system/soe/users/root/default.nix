{pkgs, ...}: let
  username = "root";
in {
  users.users.${username} = {
    name = username;
    shell = pkgs.bash;

    isSystemUser = true;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$ZaC141a/ldxOvTvc$fRUysX6LjlZvnPiRcp4uG.dnm8RZJ1lQIFzWDZjbhkVpJXW2jDHor13rJ0UBTKS.k..3oaVuMi2y8Xog81iBT/";
  };
}
