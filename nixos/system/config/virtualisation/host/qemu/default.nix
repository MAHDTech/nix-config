{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    OVMFFull
    qemu
    #qemu_full # Include CEPH/RBD support
  ];

  environment = {
    etc = {
      "qemu/bridge.conf" = {
        text = ''
          #allow br0
        '';
        mode = "0644";
      };
    };
  };

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
