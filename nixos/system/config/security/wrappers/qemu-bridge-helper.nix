{ pkgs, ... }:
{
  security = {
    wrappers = {
      qemu-bridge-helper = {
        setuid = true;
        owner = "root";
        group = "kvm";
        source = "${pkgs.qemu}/libexec/qemu-bridge-helper";
      };
    };
  };
}
