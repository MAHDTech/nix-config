{
  # AppArmor policy for Docker containers.
  "docker-default" = {
    state = "complain"; # TODO: Change to 'enforce' when policy has been tested.
    profile = ''
      #include <tunables/global>

      profile docker-default flags=(attach_disconnected,mediate_deleted) {
        #include <abstractions/base>

        # Allow basic container operations
        capability chown,
        capability dac_override,
        capability dac_read_search,
        capability fowner,
        capability fsetid,
        capability kill,
        capability setgid,
        capability setuid,
        capability setpcap,
        capability net_bind_service,
        capability sys_chroot,
        capability mknod,
        capability audit_write,
        capability setfcap,

        # Allow access to container directories
        /var/lib/docker/** rwmk,
        /var/run/docker.sock rw,

        # Allow network operations
        network inet,
        network inet6,

        # Allow basic system operations
        /proc/** r,
        /sys/** r,

        # Allow Docker binary execution
        /nix/store/*/bin/docker rix,
      }
    '';
  };
}
