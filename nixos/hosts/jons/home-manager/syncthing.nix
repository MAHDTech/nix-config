{
  syncthingConfig = {
    deviceName = "JONS";
    deviceId = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
    otherDevices = [
      {
        name = "ZENBOOK";
        id = "XKSODQK-74XAIJW-2RAMYBQ-MJV5DHL-CN6MXTJ-AJ6X6BM-JU2SAXG-TRKDPAN";
        autoAcceptFolders = false;
      }
      {
        name = "ORION";
        id = "BADYXG2-HRDVBNF-QVA742J-VPYZMDN-IED2CTO-VTPXTXQ-J6VRXV6-IIFSMQG";
        autoAcceptFolders = false;
      }
    ];
    syncFolders = {
      "Sync" = {

        enable = false;
        id = "syncthing-shared";
        path = "/home/mahdtech/Sync";
        type = "sendreceive";

        devices = [
          "ZENBOOK"
          "ORION"
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
