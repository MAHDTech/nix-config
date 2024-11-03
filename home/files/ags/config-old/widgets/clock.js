import { DataCurrentTime } from "../data/date.js";

export function WidgetClock() {
  return Widget.Label({
    class_name: "clock",

    label: DataCurrentTime.bind(),
  });
}
