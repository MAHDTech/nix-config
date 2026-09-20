{ ... }:
{
  imports = [ ../common ];

  hosts.github-runner = {
    runnerGroup = "tars-cloud";
    tokenReference = "op://fleet/GitHub Runner/credential";
  };
}
