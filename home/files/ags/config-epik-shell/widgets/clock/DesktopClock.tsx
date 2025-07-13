import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { range, time } from "../../utils"
import { Binding } from "astal"
import options from "../../options"

function Number({ shown }: { shown: string | Binding<string> }) {
  return (
    <box cssClasses={["number-box"]} valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER}>
      <stack visibleChildName={shown} transitionType={Gtk.StackTransitionType.SLIDE_UP} transitionDuration={1000}>
        {range(9).map((v) => (
          <label name={v.toString()} label={v.toString()} />
        ))}
      </stack>
    </box>
  )
}

function UnitBox({ label, shown1, shown2 }: { label: string; shown1: string | Binding<string>; shown2: string | Binding<string> }) {
  return (
    <box vertical cssClasses={["unit"]}>
      <box halign={Gtk.Align.CENTER} hexpand>
        <Number shown={shown1} />
        <Number shown={shown2} />
      </box>
      <label cssClasses={["box-label"]} label={label} />
    </box>
  )
}

export default function DesktopClock(_gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor
  const handlePos = (pos: string) => {
    switch (pos) {
      case "top_left":
        return TOP | LEFT
      case "top":
        return TOP
      case "top_right":
        return TOP | RIGHT
      case "left":
        return LEFT
      case "right":
        return RIGHT
      case "bottom_left":
        return BOTTOM | LEFT
      case "bottom":
        return BOTTOM
      case "bottom_right":
        return BOTTOM | RIGHT
      default:
        return undefined as unknown as Astal.WindowAnchor
    }
  }

  return (
    <window
      setup={(self) => {
        self.set_default_size(1, 1)
      }}
      visible
      layer={Astal.Layer.BOTTOM}
      gdkmonitor={_gdkmonitor}
      name={"clock"}
      namespace={"clock"}
      anchor={options.desktop_clock.position(handlePos)}
      application={App}
    >
      <box cssClasses={["clock-container"]} spacing={6}>
        <UnitBox label={"Hours"} shown1={time((t) => t.format("%H")!.split("")[0])} shown2={time((t) => t.format("%H")!.split("")[1])} />
        <label label={":"} />
        <UnitBox label={"Minutes"} shown1={time((t) => t.format("%M")!.split("")[0])} shown2={time((t) => t.format("%M")!.split("")[1])} />
        <label label={":"} />
        <UnitBox label={"Seconds"} shown1={time((t) => t.format("%S")!.split("")[0])} shown2={time((t) => t.format("%S")!.split("")[1])} />
      </box>
    </window>
  )
}
