{config, ...}: {
  # Fancontrol is the shell script inside of lm-sensors.
  hardware = {
    fancontrol = {
      enable = false;
      config = ''
        INTERVAL=10
        DEVPATH=hwmon3=devices/virtual/thermal/thermal_zone2 hwmon4=devices/platform/f71882fg.656
        DEVNAME=hwmon3=soc_dts1 hwmon4=f71869a
        FCTEMPS=hwmon4/device/pwm1=hwmon3/temp1_input
        FCFANS=hwmon4/device/pwm1=hwmon4/device/fan1_input
        MINTEMP=hwmon4/device/pwm1=35
        MAXTEMP=hwmon4/device/pwm1=65
        MINSTART=hwmon4/device/pwm1=150
        MINSTOP=hwmon4/device/pwm1=0
      '';
    };
  };

  # Thinkfan now works with non ThinkPads.
  # For testing;
  # sudo thinkfan -n -b -5 -c /tmp/thinkfan.yaml
  services = {
    thinkfan = {
      enable = false;

      # Check thinkfan man page.
      extraArgs = [];

      # Enable to build thinkfan with S.M.A.R.T support.
      smartSupport = true;

      # Configure the settings not exposed in NixOS.
      settings = {};

      # Fans (only 1 is currently supported)
      # Common paths;
      # - /sys/class/hwmon/hwmon0/pwm1
      # - /sys/class/graphics/fb0/device/hwmon
      # Type can be;
      #   hwmon for standard sensor
      #   atasmart for HDD
      #   tpacpi for ThinkPad ACPI
      fans = [
        {
          type = "tpacpi";
          query = "/proc/acpi/ibm/fan";
        }
      ];

      # Temperature sensors.
      # Discover these with
      # find /sys/devices -type f -name "temp*_input"
      # Type can be;
      #   hwmon for standard sensor
      #   atasmart for HDD
      #   tpacpi for ThinkPad ACPI
      #   nvm1 for NVIDIA driver
      sensors = [
        # CPU
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp10_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp14_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp18_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp1_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp22_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp26_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp27_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp28_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp29_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp2_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp31_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp32_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp33_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp6_input";
        }
        # System
        {
          type = "hwmon";
          query = "/sys/devices/virtual/thermal/thermal_zone0/hwmon4/temp1_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/virtual/thermal/thermal_zone2/hwmon7/temp1_input";
        }
        # HDD
        {
          type = "hwmon";
          query = "/sys/devices/pci0000:00/0000:00:1d.0/0000:3e:00.0/nvme/nvme0/hwmon0/temp1_input";
        }
        {
          type = "hwmon";
          query = "/sys/devices/pci0000:00/0000:00:06.0/0000:04:00.0/nvme/nvme1/hwmon1/temp1_input";
        }
        {
          type = "atasmart";
          query = "/dev/disk/by-id/nvme-Corsair_MP600_PRO_NH_A5JVB4273059HX";
        }
        {
          type = "atasmart";
          query = "/dev/disk/by-id/nvme-Corsair_MP600_PRO_NH_A5JVB427305AF2";
        }
      ];

      # LEVEL,  LOW,  HIGH
      #
      # LEVEL can be;
      #   0-7
      #   "level auto"
      #   "level full-speed"
      #   "level disengaged"
      #
      # LOW is the temp when to step down to the previous LEVEL.
      # HIGH is the temp when to step up to the next LEVEL.
      levels = [
        # When the temp is from 0 to 25
        [0 0 25]
        # When the temp is from 25 to 30
        [1 25 30]
        # When the temp is from 30 to 35
        [2 30 35]
        # When the temp is from 35 to 40
        [3 35 40]
        # When the temp is from 40 to 45
        [4 40 45]
        # When the temp is from 45 to 50
        [5 45 50]
        # When the temp is from 50 to 55
        ["level auto" 50 55]
        # When the level is from 50 to 60
        ["level full-speed" 55 60]
        # When the temp is greater than 60
        ["level disengaged" 60 32767]
      ];
    };
  };
}
