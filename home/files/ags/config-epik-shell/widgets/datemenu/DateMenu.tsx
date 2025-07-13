import { App, Gtk, Gdk } from "astal/gtk4"
import PopupWindow from "../common/PopupWindow"
import { Variable } from "astal"
import options from "../../options"

export const WINDOW_NAME = "datemenu-window"

const { bar } = options

const layout = Variable.derive([bar.position, bar.start, bar.center, bar.end], (pos, start, center, end) => {
  if (start.includes("time")) return `${pos}_left`
  if (center.includes("time")) return `${pos}_center`
  if (end.includes("time")) return `${pos}_right`

  return `${pos}_center`
})

function DateMenu(_gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow name={WINDOW_NAME} animation="slide top" layout={layout.get()} onDestroy={() => layout.drop()}>
      <box vertical cssClasses={["window-content", "datemenu-container"]}>
        <Gtk.Calendar />
      </box>
    </PopupWindow>
  )
}

export default function (_gdkmonitor: Gdk.Monitor) {
  DateMenu(_gdkmonitor)
  layout.subscribe(() => {
    App.remove_window(App.get_window(WINDOW_NAME)!)
    DateMenu(_gdkmonitor)
  })
}
