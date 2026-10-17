{ pkgs }:
let
  stateVersion = import ../lib/stateVersion.nix;
  fakeNotifySend = pkgs.writeShellScript "fake-notify-send" ''
    echo "$*" >> /tmp/notifications.log
  '';
in
pkgs.testers.runNixOSTest {
  name = "clamav-notify";
  nodes.machine =
    { ... }:
    {
      system.stateVersion = stateVersion;
      imports = [ ../nixos/system/config/services/clamav-notify ];

      users = {
        users = {
          alice = {
            isNormalUser = true;
            uid = 1000;
          };
          clamav = {
            isSystemUser = true;
            group = "clamav";
          };
        };
        groups.clamav = { };
      };
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    # Verify normal user was added to systemd-journal group
    machine.succeed("id -Gn alice | grep -qw systemd-journal")

    # Simulate clamd invoking VirusEvent as the unprivileged clamav user
    machine.succeed(
        "su -s /bin/sh clamav -c '"
        "CLAM_VIRUSEVENT_FILENAME=\"/home/alice/Downloads/bad:file (1).bin\" "
        "CLAM_VIRUSEVENT_VIRUSNAME=\"Win.Test.EICAR_HDB-1\" "
        "clamav-notify emit-event'"
    )

    # Run daemon --once as alice and verify inbox ingestion + desktop notification
    machine.succeed(
        "su - alice -c '"
        "CLAMAV_NOTIFY_SEND_BIN=${fakeNotifySend} "
        "clamav-notify daemon --once'"
    )
    machine.succeed("grep -q 'Win.Test.EICAR_HDB-1' /tmp/notifications.log")
    machine.succeed("su - alice -c 'clamav-notify list --status open | grep -q \"bad:file (1).bin\"'")

    # Snooze alert #1 for 1h and verify repeat detection increments hit count without new popup
    machine.succeed("rm -f /tmp/notifications.log")
    machine.succeed("su - alice -c 'clamav-notify snooze 1 1h'")
    machine.succeed("su - alice -c 'clamav-notify list --status snoozed | grep -q SNOOZE'")

    machine.succeed(
        "su -s /bin/sh clamav -c '"
        "CLAM_VIRUSEVENT_FILENAME=\"/home/alice/Downloads/bad:file (1).bin\" "
        "CLAM_VIRUSEVENT_VIRUSNAME=\"Win.Test.EICAR_HDB-1\" "
        "clamav-notify emit-event'"
    )
    machine.succeed(
        "su - alice -c '"
        "CLAMAV_NOTIFY_SEND_BIN=${fakeNotifySend} "
        "clamav-notify daemon --once'"
    )
    machine.succeed("test ! -f /tmp/notifications.log")
    machine.succeed("su - alice -c 'clamav-notify list --json | grep -q \"\\\"hit_count\\\": 2\"'")

    # Close alert #1, then emit another VirusEvent and verify it re-opens and notifies
    machine.succeed("su - alice -c 'clamav-notify close 1'")
    machine.succeed("su - alice -c 'clamav-notify list --status closed | grep -q CLOSED'")

    machine.succeed(
        "su -s /bin/sh clamav -c '"
        "CLAM_VIRUSEVENT_FILENAME=\"/home/alice/Downloads/bad:file (1).bin\" "
        "CLAM_VIRUSEVENT_VIRUSNAME=\"Win.Test.EICAR_HDB-1\" "
        "clamav-notify emit-event'"
    )
    machine.succeed(
        "su - alice -c '"
        "CLAMAV_NOTIFY_SEND_BIN=${fakeNotifySend} "
        "clamav-notify daemon --once'"
    )
    machine.succeed("grep -q 'Win.Test.EICAR_HDB-1' /tmp/notifications.log")
    machine.succeed("su - alice -c 'clamav-notify list --status open | grep -q OPEN'")
    machine.succeed("su - alice -c 'clamav-notify list --json | grep -q \"\\\"hit_count\\\": 3\"'")

    # Close and clear-closed
    machine.succeed("su - alice -c 'clamav-notify close 1'")
    machine.succeed("su - alice -c 'clamav-notify clear-closed'")
    machine.succeed("su - alice -c 'clamav-notify list | grep -q \"No ClamAV notifications\"'")
  '';
}
