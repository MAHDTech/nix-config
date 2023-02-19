/*

nix-shell shells/sops-nix

*/

{ mkShell
, sops-import-keys-hook
, ssh-to-pgp
, sops-init-gpg-key
, sops
, deploy-rs
, nixpkgs-fmt
, knot-dns
, lefthook
, python3
}:

mkShell {

  sopsPGPKeyDirs = [ "./secrets/keys" ];

  nativeBuildInputs = [

    python3.pkgs.invoke
    ssh-to-pgp
    sops-import-keys-hook
    sops-init-gpg-key
    sops
    deploy-rs
    nixpkgs-fmt
    lefthook
    knot-dns

  ];

}
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {

  nativeBuildInputs = [ pkgs.buildPackages.ruby_2_7 ];

}