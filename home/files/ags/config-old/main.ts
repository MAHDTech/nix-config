/* Data */

import { DataMonitors } from "./data/monitors.js";

/* Widgets */

import { WidgetBar } from "./widgets/bar.js";
//import { WidgetAppLauncher } from "./widgets/applauncher.js";
//import { WidgetMedia } from "./widgets/media.js";
//import { WidgetNotifications } from "./widgets/notifications.js";

Utils.timeout(1000, () =>
  Utils.notify({
    summary: "Notification Service",
    iconName: "info-symbolic",
    body: "Loading notification service...",
    actions: {
      OK: () => print("AGS Notification Service loaded"),
    },
  }),
);

/* App */
App.config({
  style: App.configDir + "/css/main.css",

  windows: [
    // Load the top bar for each monitor
    ...DataMonitors().map((monitor) => WidgetBar(monitor)),

    // Load the application launcher
    //WidgetAppLauncher,

    // Load the notifications widget
    //WidgetNotifications(),

    // Load the media widget
    //WidgetMedia(),
  ],
});
