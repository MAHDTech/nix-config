{ ... }:
{
  imports = [ ../github-runner/groups/tars-cloud.nix ];
  hosts.github-runner.upgradeTime = "07:00";
}
