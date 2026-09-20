{ ... }:
{
  imports = [ ../common ];

  hosts.github-runner = {
    runnerGroup = "bingamon-lab";
    tokenReference = "op://Bingamon/GitHub Runner/credential";
  };
}
