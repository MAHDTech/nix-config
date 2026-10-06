{ ... }:
{
  imports = [ ../github-runner/groups/tars-cloud.nix ];
  hosts.github-runner.upgradeTime = "00:00";
}
