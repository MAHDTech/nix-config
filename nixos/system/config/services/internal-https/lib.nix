# cspell:ignore nosniff
{ lib }:
rec {
  defaultAllowedNetworks = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "127.0.0.1/32"
    "::1/128"
  ];

  mkAllowedNetworksOption =
    description:
    lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultAllowedNetworks;
      inherit description;
    };

  nginxAllowDirectives = networks: ''
    ${lib.concatMapStringsSep "\n" (network: "allow ${network};") networks}
    deny all;
  '';

  nginxBaselineHeaders = ''
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer" always;
  '';

  nginxHtmlHeaders = csp: ''
    ${nginxBaselineHeaders}
    add_header X-Frame-Options "DENY" always;
    add_header Content-Security-Policy "${csp}" always;
  '';

  nginxRejectDefaultVirtualHost = {
    default = true;
    rejectSSL = true;
    listen = [
      {
        addr = "0.0.0.0";
        port = 443;
        ssl = true;
        extraParameters = [ "default_server" ];
      }
      {
        addr = "[::0]";
        port = 443;
        ssl = true;
        extraParameters = [ "default_server" ];
      }
    ];
    locations."/".return = "444";
  };
}
