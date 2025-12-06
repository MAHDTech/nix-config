{ pkgs, ... }:
{
  imports = [ ];

  # REMEMBER: Run these commands to reload the udev rules:
  # sudo udevadm control --reload-rules
  # sudo udevadm trigger
  # sudo udevadm settle

  services.udev = {
    enable = true;

    packages = with pkgs; [
      apio-udev-rules
      game-devices-udev-rules
      ledger-udev-rules
      logitech-udev-rules
      trezor-udev-rules
      zsa-udev-rules
    ];

    # https://github.com/spesmilo/electrum/tree/master/contrib/udev
    extraRules = ''
      # Make Thunderbolt docks great again.
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"

      # KeepKey HID Firmware/Bootloader
      SUBSYSTEM=="usb", ATTR{idVendor}=="2b24", ATTR{idProduct}=="0001", MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="keepkey%n"
      KERNEL=="hidraw*", ATTRS{idVendor}=="2b24", ATTRS{idProduct}=="0001",  MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

      # KeepKey WebUSB Firmware/Bootloader
      SUBSYSTEM=="usb", ATTR{idVendor}=="2b24", ATTR{idProduct}=="0002", MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="keepkey%n"
      KERNEL=="hidraw*", ATTRS{idVendor}=="2b24", ATTRS{idProduct}=="0002",  MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

      # HW.1, Nano
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c|2b7c|3b7c|4b7c", TAG+="uaccess", TAG+="udev-acl"

      # Blue, NanoS, Aramis, HW.2, Nano X, NanoSP, Stax, Ledger Test,
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", TAG+="uaccess", TAG+="udev-acl"

      # Same, but with hidraw-based library (instead of libusb)
      KERNEL=="hidraw*", ATTRS{idVendor}=="2c97", MODE="0666"

      # Oslo sleepbuds (Qualcomm QCC5141)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", MODE="0666", GROUP="plugdev"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0a12", ATTRS{idProduct}=="4007", MODE="0666", GROUP="plugdev"
      SUBSYSTEMS=="usb", ATTR{idVendor}=="0a12", ATTR{idProduct}=="4007", SYMLINK+="qcc5141"
      SUBSYSTEMS=="usb", ATTR{idVendor}=="0a12", ATTR{idProduct}=="4007", TAG+="systemd"

      # CH341A SPI programmer rules
      SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="5512", MODE="0666", GROUP="plugdev"

      # EOF - Extra Rules
    '';
  };
}
