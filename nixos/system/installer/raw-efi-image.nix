{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Determine architecture for systemd-boot binary
  efiArch =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      "aa64"
    else if pkgs.stdenv.hostPlatform.isx86_64 then
      "x64"
    else
      throw "Unsupported architecture for Raw EFI image: ${pkgs.stdenv.hostPlatform.system}";

  # Paths to kernel, initrd, and device tree for the ESP
  kernelTarget = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
  initrdTarget = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";

  # Check if a Device Tree is configured
  dtbPath = config.hardware.deviceTree.name;
  dtbTarget = if dtbPath != null then "${config.hardware.deviceTree.package}/${dtbPath}" else null;

  # The closure info for the root partition
  closureInfo = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };

  # Build the raw EFI disk image with proper GPT + ESP
  rawEfiImage = pkgs.stdenv.mkDerivation {
    name = "nixos-raw-efi-image-${config.networking.hostName}";

    requiredSystemFeatures = [ "uid-range" ];

    nativeBuildInputs = with pkgs; [
      dosfstools
      e2fsprogs
      util-linux
      gptfdisk
      mtools
      coreutils
      fakeroot
    ];

    buildCommand = ''
      closureInfo="${closureInfo}"

      # Calculate sizes
      espSizeMB=512
      rootSizeBytes=$(cat $closureInfo/store-paths | xargs du -sb | awk '{sum += $1} END {print sum}')
      # Add 1GB headroom above the installer closure, then enforce a 32GB
      # minimum. The minimum ensures --build-on remote always has space for
      # the full target system closure (~8-15 GB) on any host.
      closureSizeMB=$(( (rootSizeBytes / 1048576) + 1024 ))
      minRootSizeMB=32768
      rootSizeMB=$(( closureSizeMB > minRootSizeMB ? closureSizeMB : minRootSizeMB ))
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

      # Calculate partition offsets
      espStartSector=2048
      espSectors=$(( espSizeMB * 1048576 / 512 ))
      rootStartSector=$(( espStartSector + espSectors ))

      # Create ESP filesystem image
      truncate -s ''${espSizeMB}M esp.img
      mkfs.fat -F 32 -n ESP esp.img

      # Populate ESP
      mmd -i esp.img ::EFI
      mmd -i esp.img ::EFI/BOOT
      mmd -i esp.img ::loader
      mmd -i esp.img ::loader/entries
      mmd -i esp.img ::nixos

      # Copy systemd-boot binary
      mcopy -i esp.img ${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi ::EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI

      # Create loader.conf
      cat > loader.conf <<EOF
      default nixos.conf
      timeout 5
      console-mode keep
      EOF
      mcopy -i esp.img loader.conf ::loader/loader.conf

      # Create nixos.conf entry
      cat > nixos.conf <<EOF
      title NixOS Installer (${config.networking.hostName})
      linux /nixos/kernel
      initrd /nixos/initrd
      ${lib.optionalString (dtbTarget != null) "devicetree /nixos/dtb"}
      options init=${config.system.build.toplevel}/init ${lib.concatStringsSep " " config.boot.kernelParams}
      EOF
      mcopy -i esp.img nixos.conf ::loader/entries/nixos.conf

      mcopy -i esp.img ${kernelTarget} ::nixos/kernel
      mcopy -i esp.img ${initrdTarget} ::nixos/initrd
      ${lib.optionalString (dtbTarget != null) "mcopy -i esp.img ${dtbTarget} ::nixos/dtb"}

      # Write ESP image into the disk image
      dd if=esp.img of=image.raw seek=$espStartSector bs=512 conv=notrunc

      # Get exact start and size of root partition allocated by sfdisk
      rootStartSector=$(sfdisk -d image.raw | grep 'name="nixos-root"' | sed -E 's/.*start=\s*([0-9]+),.*/\1/')
      rootSectors=$(sfdisk -d image.raw | grep 'name="nixos-root"' | sed -E 's/.*size=\s*([0-9]+),.*/\1/')
      rootBytes=$(( rootSectors * 512 ))
      truncate -s $rootBytes root.img

      # Populate root filesystem
      mkdir -p root-mnt
      fakeroot -- bash -c "
        mkdir -p root-mnt/nix/store
        while read storePath; do
          cp -a \$storePath root-mnt/nix/store/
        done < $closureInfo/store-paths
        mkdir -p root-mnt/nix/var/nix/db
        cp $closureInfo/registration root-mnt/nix/var/nix/db/
        ln -sf ${config.system.build.toplevel}/init root-mnt/init
        mkdir -p root-mnt/{etc,var,tmp,proc,sys,dev,run,root}
      "
      mkfs.ext4 -L nixos-root -d root-mnt root.img

      # Write root image into the disk image
      dd if=root.img of=image.raw seek=$rootStartSector bs=512 conv=notrunc

      # Output
      mkdir -p $out
      mv image.raw $out/nixos-installer-${config.networking.hostName}.raw
    '';
  };
in
{
  system.build.image = rawEfiImage;

  # Filesystem mount for the running installer system
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
    noCheck = true;
  };
}
