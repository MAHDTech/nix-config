/* Services */
const hyprland = await Service.import("hyprland");
const notifications = await Service.import("notifications");
const mpris = await Service.import("mpris");
const audio = await Service.import("audio");
const battery = await Service.import("battery");
const systemtray = await Service.import("systemtray");

/* Widgets */
import { WidgetBar } from "./widgets/bar.js";
import { WidgetAppLauncher } from "./widgets/applauncher.js";
import { WidgetNotifications } from "./widgets/notifications.js";

App.config({
  style: App.configDir + "/style/style.css",

  windows: [
    // Load the top bar.
    WidgetBar(0),

    // Load the application launcher.
    WidgetAppLauncher,

    // Load the notifications widget.
    WidgetNotifications(),
  ],
});
