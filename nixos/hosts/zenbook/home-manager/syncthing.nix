{
  syncthingConfig = {
    deviceName = "ZENBOOK";
    deviceId = "XKSODQK-74XAIJW-2RAMYBQ-MJV5DHL-CN6MXTJ-AJ6X6BM-JU2SAXG-TRKDPAN";
    otherDevices = [
      {
        name = "JONS";
        id = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
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
          "JONS"
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
