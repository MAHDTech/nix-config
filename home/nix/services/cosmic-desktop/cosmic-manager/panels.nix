{
  wayland.desktopManager.cosmic.panels = [
    {
      name = "Panel";
      anchor = {
        __type = "enum";
        variant = "Top";
      };
      anchor_gap = false;
      autohide = {
        __type = "optional";
        value = null;
      };
      autohover_delay_ms = {
        __type = "optional";
        value = 500;
      };
      background = {
        __type = "enum";
        variant = "ThemeDefault";
      };
      border_radius = 0;
      exclusive_zone = true;
      expand_to_edges = true;
      keyboard_interactivity = {
        __type = "enum";
        variant = "OnDemand";
      };
      layer = {
        __type = "enum";
        variant = "Top";
      };
      margin = 0;
      opacity = 1.0;
      output = {
        __type = "enum";
        variant = "All";
      };
      padding = 0;
      padding_overlap = 0.5;
      plugins_center = {
        __type = "optional";
        value = [ "com.system76.CosmicAppletTime" ];
      };
      plugins_wings = {
        __type = "optional";
        value = {
          __type = "tuple";
          value = [
            [
              "com.system76.CosmicPanelWorkspacesButton"
              "com.system76.CosmicPanelAppButton"
            ]
            [
              "com.system76.CosmicAppletStatusArea"
              "com.system76.CosmicAppletA11y"
              "com.system76.CosmicAppletTiling"
              "com.system76.CosmicAppletAudio"
              "com.system76.CosmicAppletBluetooth"
              "com.system76.CosmicAppletNetwork"
              "com.system76.CosmicAppletBattery"
              "com.system76.CosmicAppletNotifications"
              "com.system76.CosmicAppletPower"
            ]
          ];
        };
      };
      size = {
        __type = "enum";
        variant = "XS";
      };
      size_center = {
        __type = "optional";
        value = null;
      };
      size_wings = {
        __type = "optional";
        value = null;
      };
      spacing = 0;
    }
    {
      name = "Dock";
      anchor = {
        __type = "enum";
        variant = "Bottom";
      };
      anchor_gap = true;
      autohide = {
        __type = "optional";
        value = null;
      };
      autohover_delay_ms = {
        __type = "optional";
        value = 500;
      };
      background = {
        __type = "enum";
        variant = "ThemeDefault";
      };
      border_radius = 160;
      exclusive_zone = true;
      expand_to_edges = false;
      keyboard_interactivity = {
        __type = "enum";
        variant = "OnDemand";
      };
      layer = {
        __type = "enum";
        variant = "Top";
      };
      margin = 4;
      opacity = 1.0;
      output = {
        __type = "enum";
        variant = "All";
      };
      padding = 4;
      plugins_center = {
        __type = "optional";
        value = [
          "com.system76.CosmicPanelLauncherButton"
          "com.system76.CosmicPanelWorkspacesButton"
          "com.system76.CosmicPanelAppButton"
          "com.system76.CosmicAppList"
          "com.system76.CosmicAppletMinimize"
        ];
      };
      plugins_wings = {
        __type = "optional";
        value = {
          __type = "tuple";
          value = [
            [ ]
            [ ]
          ];
        };
      };
      size = {
        __type = "enum";
        variant = "L";
      };
      size_center = {
        __type = "optional";
        value = null;
      };
      size_wings = {
        __type = "optional";
        value = null;
      };
      spacing = 0;
    }
  ];
}
