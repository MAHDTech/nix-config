{
  # AppArmor policy for Incus virtual machines
  "incus_vm" = {
    state = "complain"; # TODO: Change to 'enforce' when policy has been tested.
    profile = ''
      #include <tunables/global>

      profile incus_vm flags=(attach_disconnected,mediate_deleted) {
        #include <abstractions/base>

        # Allow sys_admin capability for VM operations
        capability sys_admin,

        # Allow access to Incus directories
        /var/lib/incus/** rwmk,
        /var/log/incus/** rwmk,

        # Allow QEMU operations
        /dev/kvm rw,
        /dev/vhost-net rw,
        /dev/vhost-vsock rw,

        # Allow network operations
        network inet,
        network inet6,

        # Allow basic system operations
        /proc/** r,
        /sys/** r,

        # Allow QEMU binary execution
        /nix/store/*/bin/qemu-system-* rix,

        # Allow access to libraries
        /nix/store/*/lib/*so* mr,
      }
    '';
  };
}
