import { DataCurrentTime } from "../data/date.js";

export const WidgetBar = (/** @type {number} */ monitor) =>
  Widget.Window({
    monitor,
    name: `bar${monitor}`,
    anchor: ["top", "left", "right"],
    exclusivity: "exclusive",
    child: Widget.CenterBox({
      start_widget: Widget.Label({
        hpack: "center",
        label: "Welcome to AGS!",
      }),
      end_widget: Widget.Label({
        hpack: "center",
        label: DataCurrentTime.bind(),
      }),
    }),
  });
