import { DataCurrentTime } from "../data/date.js";

export function Clock() {
  return Widget.Label({
    class_name: "clock",

    label: DataCurrentTime.bind(),
  });
}
