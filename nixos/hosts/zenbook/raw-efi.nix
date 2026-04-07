{
  pkgs,
  lib,
  inputs,
  modulesPath,
  config,
  ...
}:
let
  kernelBuild = pkgs.callPackage ./kernel.nix { inherit inputs; };

  # Paths to kernel, initrd, and device tree for the ESP
  kernelTarget = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
  initrdTarget = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
  dtbTarget = "${config.hardware.deviceTree.package}/qcom/x1e80100-asus-zenbook-a14.dtb";

  # GRUB configuration for the ESP
  grubCfg = pkgs.writeText "grub.cfg" ''
    set timeout=5
    set default=0

    menuentry "NixOS Zenbook Installer" {
      linux /nixos/kernel init=${config.system.build.toplevel}/init ${lib.concatStringsSep " " config.boot.kernelParams}
      initrd /nixos/initrd
      devicetree /nixos/dtb
    }
  '';

  # Build a standalone GRUB EFI binary for aarch64
  grubEfiImage =
    pkgs.runCommand "grub-efi-aa64"
      {
        nativeBuildInputs = [ pkgs.grub2_efi ];
      }
      ''
        mkdir -p $out

        cat > embed.cfg <<'EOF'
        search --label --set=root ESP
        set prefix=($root)/grub
        configfile ($root)/grub/grub.cfg
        EOF

        grub-mkstandalone \
          --format=arm64-efi \
          --output=$out/BOOTAA64.EFI \
          --locales="" \
          --fonts="" \
          --themes="" \
          "boot/grub/grub.cfg=embed.cfg"
      '';

  # The closure info for the root partition
  closureInfo = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };

  # Build the raw EFI disk image with proper GPT + ESP
  rawEfiImage = pkgs.stdenv.mkDerivation {
    name = "nixos-zenbook-installer";

    # This is what makes unshare --map-root-user work in the sandbox
    requiredSystemFeatures = [ "uid-range" ];

    nativeBuildInputs = with pkgs; [
      dosfstools # mkfs.fat
      e2fsprogs # mkfs.ext4, mke2fs
      util-linux # sfdisk, losetup
      gptfdisk # sgdisk
      mtools # mmd, mcopy
      coreutils
      fakeroot
    ];

    buildCommand = ''
      closureInfo="${closureInfo}"

      # Calculate sizes
      espSizeMB=512
      rootSizeBytes=$(cat $closureInfo/store-paths | xargs du -sb | awk '{sum += $1} END {print sum}')
      # Add 4096MB headroom for root to be absolutely safe
      rootSizeMB=$(( (rootSizeBytes / 1048576) + 4096 ))
      totalSizeMB=$(( espSizeMB + rootSizeMB + 2 ))

      echo "ESP: ''${espSizeMB}MB, Root: ''${rootSizeMB}MB, Total: ''${totalSizeMB}MB"


      # Create the raw disk image
      truncate -s ''${totalSizeMB}M image.raw

      # Create GPT partition table
      sfdisk image.raw <<PARTEOF
      label: gpt
      size=''${espSizeMB}MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="ESP"
      type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="nixos-root"
      PARTEOF

      # Calculate partition offsets (sector size = 512)
      espStartSector=2048
      espSectors=$(( espSizeMB * 1048576 / 512 ))
      rootStartSector=$(( espStartSector + espSectors ))

      # Create ESP filesystem image
      truncate -s ''${espSizeMB}M esp.img
      mkfs.fat -F 32 -n ESP esp.img

      # Populate ESP
      mmd -i esp.img ::EFI
      mmd -i esp.img ::EFI/BOOT
      mmd -i esp.img ::grub
      mmd -i esp.img ::nixos
      mcopy -i esp.img ${grubEfiImage}/BOOTAA64.EFI ::EFI/BOOT/BOOTAA64.EFI
      mcopy -i esp.img ${grubCfg} ::grub/grub.cfg
      mcopy -i esp.img ${kernelTarget} ::nixos/kernel
      mcopy -i esp.img ${initrdTarget} ::nixos/initrd
      mcopy -i esp.img ${dtbTarget} ::nixos/dtb

      # Write ESP image into the disk image
      dd if=esp.img of=image.raw seek=$espStartSector bs=512 conv=notrunc

      # Create root filesystem image
      rootSectors=$(( (totalSizeMB * 1048576 / 512) - rootStartSector - 34 ))
      rootBytes=$(( rootSectors * 512 ))
      truncate -s $rootBytes root.img

      # Create ext4 with the nix store
      mkfs.ext4 -L nixos-root -d root-contents root.img 2>/dev/null || {
        # If -d doesn't work, create empty and copy
        mkfs.ext4 -L nixos-root root.img
      }

      # Populate root filesystem using fakeroot for proper ownership
      mkdir -p root-mnt
      fakeroot -- bash -c "
        # Create nix store directory structure
        mkdir -p root-mnt/nix/store
        # Copy all store paths
        while read storePath; do
          cp -a \$storePath root-mnt/nix/store/
        done < $closureInfo/store-paths
        # Create registration for nix-store --load-db
        mkdir -p root-mnt/nix/var/nix/db
        cp $closureInfo/registration root-mnt/nix/var/nix/db/
        # Create init symlink
        ln -sf ${config.system.build.toplevel}/init root-mnt/init
        # Create essential directories
        mkdir -p root-mnt/{etc,var,tmp,proc,sys,dev,run,root}
      "

      # Build the ext4 image from the populated directory
      # Use the full root partition size for the image
      truncate -s $rootBytes root.img
      mkfs.ext4 -L nixos-root -d root-mnt root.img

      # Write root image into the disk image
      dd if=root.img of=image.raw seek=$rootStartSector bs=512 conv=notrunc

      # Output
      mkdir -p $out
      mv image.raw $out/nixos-zenbook-installer.raw
    '';
  };
in
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/installation-device.nix")
  ];

  boot = {
    kernelPackages = lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    initrd = {
      includeDefaultModules = false;
      allowMissingModules = true;
      availableKernelModules = lib.mkForce [
        "nvme"
        "msm"
        "ath12k"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "uas"
        "sd_mod"
        "arm_smmu"
        "qcom_geni_se"
        "qcom_smd_regulator"
        "qcom_spmi_regulator"
        "i2c_hid_of"
        "i2c_hid"
        "hid_multitouch"
        "snd_soc_x1e80100"
        "qcom_q6v5_pas"
        "qcom_sysmon"
        "qrtr_smd"
        "btrfs"
        "ext4"
        "usbnet"
        "cdc_ether"
        "cdc_ncm"
        "cdc_mbim"
        "rndis_host"
      ];
    };

    kernelParams = [
      "clk_ignore_unused"
      "pd_ignore_unused"
      "console=ttyAMA0,115200n8"
      "console=tty0"
      "earlyprintk"
      "cma=128M"
      "video=efifb"
      "fbcon=map:0"
      "arm64.nopauth"
    ];

    supportedFilesystems = lib.mkForce [
      "vfat"
      "btrfs"
      "ext4"
    ];

    # Boot is handled by GRUB embedded on the ESP, not by NixOS boot loader modules.
    loader = {
      grub.enable = false;
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
    };
  };

  # Expose the raw EFI image as the build output
  system.build.image = rawEfiImage;

  # Filesystem mounts for the running installer system
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
  };

  # Enable SSH for remote access
  services.openssh.enable = true;
  users.users.root = {
    password = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
  };

  # Essential firmware and DTB
  hardware = {
    graphics.enable = true;
    deviceTree = {
      enable = true;
      name = "qcom/x1e80100-asus-zenbook-a14.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [ (pkgs.callPackage ./firmware.nix { }) ];
  };

  networking.hostName = "zenbook-installer";
  networking.hostId = "def00003";
  nixpkgs.hostPlatform = "aarch64-linux";
  system.stateVersion = "26.05";
}
