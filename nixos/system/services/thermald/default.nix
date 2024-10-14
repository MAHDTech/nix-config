{pkgs, ...}: let
  _config = pkgs.writeTextFile {
    name = "thermal-conf";
    destination = "/thermal-conf.xml";
    executable = false;
    text = ''
      <?xml version="1.0"?>

      <!--
      Reference: https://manpages.ubuntu.com/manpages/focal/man5/thermal-conf.xml.5.html

      Fan control first, then CPU throttle next.
      -->

      <ThermalConfiguration>
        <Platform>
          <Name>Intel NUC X15 Laptop</Name>
          <ProductName>*</ProductName>
          <Preference>QUIET</Preference>
          <ThermalZones>
            <ThermalZone>
              <Type>cpu</Type>
              <TripPoints>
                <TripPoint>
                  <Temperature>50000</Temperature>
                  <type>passive</type>
                </TripPoint>
              </TripPoints>
            </ThermalZone>
          </ThermalZones>
          <CoolingDevices>
            <CoolingDevice>
              <Type>_fan_</Type>
              <Path>/proc/acpi/ibm/fan</Path>
              <WritePrefix>level </WritePrefix>
              <MinState>50</MinState>
              <MaxState>100</MaxState>
              <DebouncePeriod>10</DebouncePeriod>
            </CoolingDevice>
          </CoolingDevices>
        </Platform>
      </ThermalConfiguration>
    '';
  };
in {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.thermald = {
    enable = true;

    # If a config file is provided thermald will use that,
    # otherwise thermald will use adaptive mode.
    #configFile = "${config}/thermal-conf.xml";
  };
}
