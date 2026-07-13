{
  wayland.desktopManager.cosmic.compositor = {
    autotile_behavior = {
      __type = "enum";
      variant = "PerWorkspace";
    };

    input_default = {
      acceleration = {
        __type = "optional";
        value = {
          profile = {
            __type = "optional";
            value = {
              __type = "enum";
              variant = "Flat";
            };
          };
          speed = {
            __type = "raw";
            value = "-0.10288643756187243";
          };
        };
      };
      state = {
        __type = "enum";
        variant = "Enabled";
      };
    };

    xkb_config = {
      layout = "us";
      model = "pc104";
      options = {
        __type = "optional";
        value = "terminate:ctrl_alt_bksp";
      };
      repeat_delay = 600;
      repeat_rate = 25;
      rules = "";
      variant = "";
    };
  };
}
