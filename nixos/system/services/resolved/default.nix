#
# systemd-resolved
#
{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.resolved = {
    enable = true;

    llmnr = "true";

    dnssec = "allow-downgrade";

    fallbackDns = ["1.1.1.1" "1.0.0.1"];

    # Local network suffixes
    domains = [
      "mahdtech.com"
      "saltlabs.cloud"
      "saltlabs.tech"
    ];

    extraConfig = "";
  };
}
