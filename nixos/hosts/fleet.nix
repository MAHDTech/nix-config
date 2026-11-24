let
  domain = "slopageddon.app";
  runnerNames = builtins.genList (
    index:
    let
      number = index + 1;
    in
    "github-runner-${if number < 10 then "0" else ""}${toString number}"
  ) 50;
in
{
  inherit domain runnerNames;
  acme = {
    tokenReference = "op://machines/Cloudflare ACME Slopageddon/token";
    email = "cloudflare@mahdtech.com";
  };
  web = {
    nixCache = "https://nix-cache.${domain}";
    mirror = "https://mirror.${domain}";
    hub = "https://hub.${domain}";
    s3Console = "https://s3-console.${domain}/rustfs/console/";
  };
  beszel = {
    url = "https://hub.${domain}";
    publicKeyReference = "op://machines/Beszel Hub/public_key";
    members = builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = {
            host = "${name}.${domain}";
            tokenReference = "op://machines/Beszel Agents/${name}";
          };
        })
        (
          runnerNames
          ++ [
            "nix-cache"
            "s3"
            "hub"
            "mirror"
          ]
        )
    );
  };
}
