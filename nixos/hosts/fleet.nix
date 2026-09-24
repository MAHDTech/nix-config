let
  runnerNames = builtins.genList (
    index:
    let
      number = index + 1;
    in
    "github-runner-${if number < 10 then "0" else ""}${toString number}"
  ) 20;
in
{
  inherit runnerNames;
  beszel = {
    url = "https://hub.slopageddon.app";
    publicKeyReference = "op://fleet/Beszel Hub/public_key";
    members = builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = {
            host = name;
            tokenReference = "op://fleet/Beszel Agents/${name}";
          };
        })
        (
          runnerNames
          ++ [
            "nix-cache"
            "s3"
            "hub"
          ]
        )
    );
  };
}
