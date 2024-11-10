/* Widgets */

import { WidgetBatteryLevel } from "./battery.js";
import { WidgetClientTitle } from "./client-title.js";
import { WidgetClock } from "./clock.js";
import { WidgetMediaButton, WidgetMediaVolume } from "./media.js";
import { WidgetNotifications } from "./notifications.js";
import { WidgetSysTray } from "./systray.js";
import { WidgetWorkspaces } from "./workspaces.js";

/* Layout */

/* LEFT */
function Left() {
  return Widget.Box({
    hpack: "start",
    spacing: 10,
    children: [WidgetWorkspaces(), WidgetClientTitle()],
  });
}

/* CENTER */
function Center() {
  return Widget.Box({
    hpack: "center",
    spacing: 10,
    children: [WidgetMediaButton(), WidgetNotifications()],
  });
}

/* RIGHT */
function Right() {
  return Widget.Box({
    hpack: "end",
    spacing: 10,
    children: [WidgetMediaVolume(), WidgetBatteryLevel(), WidgetClock(), WidgetSysTray()],
  });
}

export function WidgetBar(monitor = 0) {
  return Widget.Window({
    // Name must be unique per monitor.
    name: `WidgetBar-${monitor}`,
    class_name: "bar",
    monitor,
    anchor: ["top", "left", "right"],
    exclusivity: "exclusive",
    child: Widget.CenterBox({
      start_widget: Left(),
      center_widget: Center(),
      end_widget: Right(),
    }),
  });
}
