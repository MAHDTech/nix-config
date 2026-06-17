{
  syncthingConfig = {
    deviceName = "JONS";
    deviceId = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
    otherDevices = [
      {
        name = "ZENBOOK";
        id = "5OMWOIZ-FCGYWTH-TH44NAN-E7E5ZZY-IH46JFI-WW7NFNQ-277EVN4-JWATRAX";
        autoAcceptFolders = false;
      }
      {
        name = "ORION";
        id = "JEGNUGP-VXS5XP6-UDTMO77-MDXQUUY-X26NX3S-RTPGMWU-SI7FHD3-FSHHMQU";
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
          "ZENBOOK"
          "ORION"
        ];
      };
    };
  };
}
