{
  # AppArmor policy for Incus LXC containers
  "incus-lxc" = {
    state = "complain"; # TODO: Change to 'enforce' when policy has been tested.
    profile = ''
      #include <tunables/global>

      profile incus-lxc flags=(attach_disconnected,mediate_deleted) {
        #include <abstractions/base>
        #include <abstractions/lxc/container-base>

        # Allow access to Incus directories
        /var/lib/incus/** rwmk,
        /var/log/incus/** rwmk,

        # Allow basic container operations
        capability,
        file,
        umount,
        mount,

        # Allow network
        network,

        # Allow /nix/store access for NixOS specifics
        /nix/store/** rix,

        # Specifically allow gzip and tar operations
        /nix/store/**/gzip** rix,
        /nix/store/**/tar** rix,
        /dev/tty rw,

        # Allow proc/sys access
        /proc/** rw,
        /sys/** r,

        # Allow access to libraries
        /nix/store/*/lib/*so* mr,
      }
    '';
  };

  # AppArmor policy for OCI containers
  "incus-oci" = {
    state = "complain"; # TODO: Change to 'enforce' when policy has been tested.
    profile = ''
      #include <tunables/global>

      profile incus-oci flags=(attach_disconnected,mediate_deleted) {
        #include <abstractions/base>

        # Allow access to Incus directories
        /var/lib/incus/** rwmk,
        /var/log/incus/** rwmk,

        # Allow OCI-specific operations (e.g., unpacking images)
        capability sys_admin,
        file,
        umount,
        mount,

        # Allow network
        network,

        # Allow /nix/store access for NixOS specifics
        /nix/store/** rix,

        # Specifically allow gzip and tar for unpacking
        /nix/store/**/gzip** rix,
        /nix/store/**/tar** rix,
        /dev/tty rw,

        # Allow proc/sys access
        /proc/** rw,
        /sys/** r,

        # Allow execution of wrapped binaries
        /nix/store/**/.**-wrapped rix,

        # Allow access to libraries
        /nix/store/*/lib/*so* mr,
      }
    '';
  };

  # AppArmor policy for Incus virtual machines
  "incus-vm" = {
    state = "complain"; # TODO: Change to 'enforce' when policy has been tested.
    profile = ''
      #include <tunables/global>

      profile incus-vm flags=(attach_disconnected,mediate_deleted) {
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
