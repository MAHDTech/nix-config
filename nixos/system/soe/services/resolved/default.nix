{ config, ... }:
{
  imports = [ ];

  # Slopageddon is served from AD without DNSSEC
  environment.etc."dnssec-trust-anchors.d/local.negative".text = ''
    slopageddon.app
  '';

  systemd.services.systemd-resolved.reloadTriggers = [
    config.environment.etc."dnssec-trust-anchors.d/local.negative".source
  ];

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        DNSSEC = "allow-downgrade";
        LLMNR = "true";
        FallbackDNS = "1.1.1.1 1.0.0.1";
        Domains = "mahdtech.com saltlabs.cloud tars-cloud.ai";

      };
    };
  };
}
