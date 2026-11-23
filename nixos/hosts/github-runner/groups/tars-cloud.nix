{ ... }:
{
  imports = [ ../common ];

  hosts.github-runner = {
    runnerGroup = "tars-cloud";
    tokenReference = "op://machines/GitHub Runner/credential";
  };
}
