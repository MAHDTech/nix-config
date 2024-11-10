{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # GNOME Partition Magic and associated tooling.
    gparted
    btrfs-progs
    exfatprogs
    e2fsprogs
    f2fs-tools
    dosfstools
    hfsprogs
    jfsutils
    util-linux
    cryptsetup
    lvm2
    nilfs-utils
    ntfs3g
    reiser4progs
    xfsprogs
  ];
}
