{ inputs, config, lib, pkgs, ... }:

let

  username = "root";

in {

  users.users.${username} = {

    name = username;
    shell = pkgs.bash;

    isSystemUser = true;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$7ndPIiBut62qO.vF$FUAAVaUSFg4oYqgRDuL6se6.EKGRzOL6wca.bd5g2cQ1chuKrl9pIZeBkswWRLazMbXsmPvlhpC9uquQrjhTR1";

  };

}