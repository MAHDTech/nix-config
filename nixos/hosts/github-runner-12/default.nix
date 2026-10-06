{ ... }:
{
  imports = [ ../github-runner/groups/tars-cloud.nix ];
  hosts.github-runner.upgradeTime = "12:00";
}
