#!/usr/bin/env nix-build

{ system ? builtins.currentSystem }:

let

  devshell = import ./. { inherit system; };

in

devshell.fromTOML ./devshell.toml
