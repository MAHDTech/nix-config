{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.resolved = {
    enable = false;

    llmnr = "true";

    dnssec = "allow-downgrade";

    fallbackDns = ["1.1.1.1" "1.0.0.1"];

    domains = [
      "mahdtech.com"
      "saltlabs.tech"
      "saltlabs.cloud"
      "vmware.local"
    ];

    extraConfig = "";
  };
}
