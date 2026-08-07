{ pkgs, ... }:
let
  # JONS is the only host with the Cezanne iGPU + Arc B580 split, so this wrapper
  # lives here rather than in system/config/games — that module is shared and the
  # PCI address below is host-specific.
  #
  # DRI_PRIME is addressed by PCI ID rather than the more common DRI_PRIME=1.
  # The numeric form is an index into Mesa's device list and silently re-points at
  # a different GPU if enumeration order ever changes; the pci- form names the Arc
  # outright. Underscores, not colons — Mesa's parser rejects the lspci spelling.
  #
  # Note this is PRIME render *offload*, not a direct scanout: no monitor is
  # attached to the Arc (see the seat-untagging udev rule in ./default.nix), so
  # each rendered frame is copied to the AMD APU to be displayed. Moving a cable
  # to the B580 would remove that copy.
  driPrime = "pci-0000_03_00_0";

  bar-arc = pkgs.writeShellScriptBin "bar-arc" ''
    exec env DRI_PRIME=${driPrime} \
      ${pkgs.beyond-all-reason}/bin/beyond-all-reason --no-sandbox "$@"
  '';

  bar-arc-desktop = pkgs.makeDesktopItem {
    name = "beyond-all-reason-arc";
    desktopName = "Beyond-All-Reason (Arc B580)";
    comment = "Beyond All Reason, rendered on the Intel Arc B580";
    exec = "${bar-arc}/bin/bar-arc %U";
    # Reuses the icon from the stock beyond-all-reason package, which the shared
    # games module already puts in the system icon path on this host.
    icon = "beyond-all-reason";
    terminal = false;
    categories = [ "Game" ];
    startupWMClass = "Beyond-All-Reason";
  };
in
{
  environment.systemPackages = [
    bar-arc
    bar-arc-desktop
  ];
}
