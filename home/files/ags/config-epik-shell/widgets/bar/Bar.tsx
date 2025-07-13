import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import TimePanelButton from "./TimePanelButton"
import WorkspacesPanelButton from "./WorkspacesPanelButton"
import NetworkSpeedPanelButton from "./NetworkSpeedPanelButton"
import RecordIndicatorPanelButton from "./RecordIndicatorPanelButton"
import LauncherPanelButton from "./LauncherPanelButton"
import NotifPanelButton from "./NotifPanelButton"
import QSPanelButton from "./QSPanelButton"
import { separatorBetween } from "../../utils"
import options from "../../options"
import { idle } from "astal"
import { windowAnimation } from "../../utils/hyprland"
import { WindowProps } from "astal/gtk4/widget"
import TrayPanelButton from "./TrayPanelButton"

const { bar } = options
const { start, center, end } = bar

const panelButton = {
  launcher: () => <LauncherPanelButton />,
  workspace: () => <WorkspacesPanelButton />,
  time: () => <TimePanelButton />,
  notification: () => <NotifPanelButton />,
  network_speed: () => <NetworkSpeedPanelButton />,
  quicksetting: () => <QSPanelButton />,
}

function Start() {
  return (
    <box halign={Gtk.Align.START}>
      {start((s) => [
        ...separatorBetween(
          s.map((s) => panelButton[s]()),
          Gtk.Orientation.VERTICAL
        ),
        <RecordIndicatorPanelButton />,
      ])}
    </box>
  )
}

function Center() {
  return (
    <box>
      {center((c) =>
        separatorBetween(
          c.map((w) => panelButton[w]()),
          Gtk.Orientation.VERTICAL
        )
      )}
    </box>
  )
}

function End() {
  return (
    <box halign={Gtk.Align.END}>
      {end((e) =>
        separatorBetween(
          e.map((w) => panelButton[w]()),
          Gtk.Orientation.VERTICAL
        )
      )}
    </box>
  )
}

type BarProps = WindowProps & {
  gdkmonitor: Gdk.Monitor
  animation: string
}
function Bar({ gdkmonitor, ...props }: BarProps) {
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor
  const anc = bar.position.get() == "top" ? TOP : BOTTOM

  return (
    <window
      visible
      setup={(self) => {
        // problem when change bar size via margin/padding live
        // https://github.com/wmww/gtk4-layer-shell/issues/60
        self.set_default_size(1, 1)
      }}
      name={"bar"}
      namespace={"bar"}
      gdkmonitor={gdkmonitor}
      anchor={anc | LEFT | RIGHT}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      application={App}
      {...props}
    >
      <centerbox cssClasses={["bar-container"]}>
        <Start />
        <Center />
        <End />
      </centerbox>
    </window>
  )
}

export default function (gdkmonitor: Gdk.Monitor) {
  ;<Bar gdkmonitor={gdkmonitor} animation="slide top" />

  bar.position.subscribe(() => {
    App.toggle_window("bar")
    const barWindow = App.get_window("bar")!
    barWindow.set_child(null)
    App.remove_window(App.get_window("bar")!)
    idle(() => {
      ;<Bar gdkmonitor={gdkmonitor} animation="slide top" />
      windowAnimation()
    })
  })
}
