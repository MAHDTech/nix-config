{ pkgs }:
pkgs.writeShellApplication {
  name = "nixos-drain";
  runtimeInputs = [
    pkgs.python3
    pkgs.systemd
    pkgs.util-linux
  ];
  text = ''
    NIXOS_DRAIN_EXECUTABLE="$(${pkgs.coreutils}/bin/readlink -f "$0")"
    export NIXOS_DRAIN_EXECUTABLE
    exec python3 ${./drain.py} "$@"
  '';
}
