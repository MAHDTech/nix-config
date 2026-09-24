{ ... }:
{
  imports = [ ../github-runner/groups/bingamon-lab.nix ];
  hosts.github-runner.upgradeTime = "09:00";
}
