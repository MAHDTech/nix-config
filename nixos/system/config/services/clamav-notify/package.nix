{ pkgs }:
pkgs.rustPlatform.buildRustPackage {
  pname = "clamav-notify";
  version = "0.1.0";

  src = pkgs.lib.fileset.toSource {
    root = ./.;
    fileset = pkgs.lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkgs.clippy
    pkgs.makeWrapper
  ];

  preCheck = ''
    cargo clippy --all-targets -- -D warnings
  '';

  postInstall = ''
    wrapProgram $out/bin/clamav-notify \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.libnotify
          pkgs.systemd
        ]
      }
  '';

  meta = {
    description = "ClamAV notification daemon, inbox, and interactive TUI";
    mainProgram = "clamav-notify";
  };
}
