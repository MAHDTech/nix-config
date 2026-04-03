{ ... }:
{
  imports = [ ];

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        DNSSEC = "allow-downgrade";
        LLMNR = "true";
        FallbackDNS = "1.1.1.1 1.0.0.1";
        Domains = "mahdtech.com saltlabs.cloud saltlabs.tech";
      };
    };
  };
}
