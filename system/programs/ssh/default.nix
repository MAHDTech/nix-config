{ inputs, config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  programs.ssh = {

    # Managed per-user with Home Manager.
    startAgent = false;

    # New versions of OpenSSH seem to default to disallowing all `ssh-add -s`
    # calls when no whitelist is provided, so this becomes necessary.
    agentPKCS11Whitelist = "${pkgs.opensc}/lib/opensc-pkcs11.so";

    # NOTE: To add keys from Yubikey
    # ssh-add -e /run/current-system/sw/lib/opensc-pkcs11.so
    # ssh-add -s /run/current-system/sw/lib/opensc-pkcs11.so

  };

}