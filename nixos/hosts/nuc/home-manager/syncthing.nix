{
  syncthingConfig = {
    deviceName = "NUC";
    deviceId = "XKSODQK-74XAIJW-2RAMYBQ-MJV5DHL-CN6MXTJ-AJ6X6BM-JU2SAXG-TRKDPAN";
    otherDevices = [
      {
        name = "JONS";
        id = "REPLACE_WITH_JONS_DEVICE_ID";
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
          "JONS"
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
