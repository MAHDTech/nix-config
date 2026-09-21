{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in
pkgs.writeShellApplication {
  name = "nixos-bootstrap";
  runtimeInputs = [ python ];
  text = ''
    exec ${python}/bin/python3 ${./worker.py} "$@"
  '';
}
