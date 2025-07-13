import { App } from "astal/gtk4"
import windows from "./windows"
import request from "./request"
import initStyles from "./utils/styles"
import initHyprland from "./utils/hyprland"

initStyles()

App.start({
  requestHandler(req, res) {
    request(req, res)
  },
  main() {
    windows.map((win) => App.get_monitors().map(win))
    initHyprland()
  },
})
