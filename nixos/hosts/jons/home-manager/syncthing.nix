{
  syncthingConfig = {
    deviceName = "JONS";
    deviceId = "REPLACE_WITH_JONS_DEVICE_ID";
    otherDevices = [
      {
        name = "NUC";
        id = "XKSODQK-74XAIJW-2RAMYBQ-MJV5DHL-CN6MXTJ-AJ6X6BM-JU2SAXG-TRKDPAN";
        autoAcceptFolders = false;
      }
    ];
    syncFolders = {
      "Syncthing" = {

        enable = true;
        id = "syncthing-shared";
        path = "/home/mahdtech/Syncthing";
        type = "sendreceive";

        devices = [
          "NUC"
        ];
        versioning = {
          type = "simple";
          params = {
            keep = "10";
          };
        };
      };
    };
  };
}
