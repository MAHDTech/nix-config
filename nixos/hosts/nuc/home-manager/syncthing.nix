{
  syncthingConfig = {
    deviceName = "NUC";
    deviceId = "XKSODQK-74XAIJW-2RAMYBQ-MJV5DHL-CN6MXTJ-AJ6X6BM-JU2SAXG-TRKDPAN";
    otherDevices = [
      {
        name = "JONS";
        id = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
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
