{ config, lib, pkgs, ... }:

let

  username = "root";

in {

  users.users.${username} = {

    name = username;
    shell = pkgs.bash;

    isSystemUser = true;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$Ashin4XGbqsek1XL$GwZv0fSwABFuSgbb0QW.duASESVUFTg.9vbqC4B/HZ3dwNpiwmCcgLOYiQZiFS9qUmZUXsfjTcvpOpK0wGkkp1";

  };

}