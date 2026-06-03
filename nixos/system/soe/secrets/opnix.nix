_: {
  services.onepassword-secrets = {
    enable = true;
    tokenFile = "/etc/opnix-token";
    secrets = {
      "daisyuiEmail" = {
        reference = "op://fleet/DaisyUI/email";
        path = "/run/secrets/daisyui-email";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "daisyuiPassword" = {
        reference = "op://fleet/DaisyUI/password";
        path = "/run/secrets/daisyui-password";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };

  # Declaratively ensure `/etc/opnix-token` is readable by the `wheel` group
  # so Home Manager (running as user) can fetch user-level secrets.
  systemd.tmpfiles.rules = [
    "z /etc/opnix-token 0640 root wheel - -"
  ];
}
