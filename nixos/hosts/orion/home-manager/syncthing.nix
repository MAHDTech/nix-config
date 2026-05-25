{
  syncthingConfig = {
    deviceName = "ORION";
    deviceId = "BADYXG2-HRDVBNF-QVA742J-VPYZMDN-IED2CTO-VTPXTXQ-J6VRXV6-IIFSMQG";
    otherDevices = [
      {
        name = "JONS";
        id = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
        autoAcceptFolders = false;
      }
      {
        name = "ZENBOOK";
        id = "XKSODQK-74XAIJW-2RAMYBQ-MJV5DHL-CN6MXTJ-AJ6X6BM-JU2SAXG-TRKDPAN";
        autoAcceptFolders = false;
      }
    ];
    syncFolders = {
      "Sync" = {

        enable = true;
        id = "syncthing-shared";
        path = "/home/mahdtech/Sync";
        type = "sendreceive";

        devices = [
          "JONS"
          "ZENBOOK"
        ];

      };
    };
  };
}
