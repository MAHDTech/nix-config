{
  syncthingConfig = {
    deviceName = "JONS";
    deviceId = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
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
