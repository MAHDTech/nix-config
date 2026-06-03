_: {
  programs.onepassword-secrets = {
    enable = true;
    secrets = {
      "daisyuiEmail" = {
        reference = "op://fleet/DaisyUI/email";
        path = ".config/daisyui/email";
        mode = "0600";
      };
      "daisyuiLicense" = {
        reference = "op://fleet/DaisyUI/license";
        path = ".config/daisyui/license";
        mode = "0600";
      };
      "sshPrivateKey" = {
        reference = "op://fleet/SSH Key/private key";
        path = ".ssh/id_ed25519";
        mode = "0600";
      };
    };
  };
}
