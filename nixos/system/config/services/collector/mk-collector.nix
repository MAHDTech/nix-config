{
  description,
  user,
  group,
  stateDirectory,
  execStart,
  after ? [ ],
  wants ? [ ],
  path ? [ ],
  timeoutStartSec ? "2min",
  memoryMax ? "128M",
  onBootSec ? "1min",
  onCalendar ? "*:0/15",
  needsNetwork ? false,
}:
{
  service = {
    inherit
      description
      after
      wants
      path
      ;
    environment.PYTHONPATH = "${./.}";
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = group;
      StateDirectory = stateDirectory;
      StateDirectoryMode = "0755";
      ExecStart = execStart;
      TimeoutStartSec = timeoutStartSec;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateNetwork = !needsNetwork;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      Nice = 10;
      IOSchedulingClass = "idle";
      MemoryMax = memoryMax;
    };
  };
  timer = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = onBootSec;
      OnCalendar = onCalendar;
      Persistent = true;
    };
  };
}
