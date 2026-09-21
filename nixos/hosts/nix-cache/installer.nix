{ lib, ... }:
{
  imports = [ ../base-qemu ];
  image.format = lib.mkForce "raw";
}
