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
    };
  };
}
