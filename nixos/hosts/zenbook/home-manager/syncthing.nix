{
  syncthingConfig = {
    deviceName = "ZENBOOK";
    deviceId = "I3ZWVSA-5ZI5N2M-M4UXHYX-V7EK4EQ-Y4ZQGOQ-BNN4CNN-2KJOQG4-QK6ZBAS";
    otherDevices = [
      {
        name = "JONS";
        id = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
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
          "JONS"
          "ORION"
        ];
      };
    };
  };
}
