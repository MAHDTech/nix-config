// Astal
import { App } from "astal/gtk3"

// Style
import style from "./style/style.scss"

// Widgets
//import Applauncher from "./widget/Applauncher";
import Bar from "./widget/Bar"
//import MprisPlayers from "./widget/MediaPlayer";
//import NotificationPopups from "./widget/NotificationPopups";

App.start({
  // The CSS stylesheet.
  css: style,

  // A unique instance name.
  instanceName: "astal",

  // For handling requests from the astal CLI client.
  requestHandler(request: string, res: (response: any) => void) {
    switch (request) {
      case "say hi":
        res("hello astal CLI")
        break
      case "launch applauncher":
        //Applauncher()
        res("launched applauncher")
        break
      default:
        res("unknown command")
        break
    }
  },

  // Main entry point.
  main() {
    // Initialize bar on all monitors
    App.get_monitors().map(Bar)

    // Initialize applauncher
    //Applauncher();

    // Initialize media player
    //new Widget.Window({}, MprisPlayers());

    // Initialize notification popups on all monitors
    //App.get_monitors().map(NotificationPopups);
  },
})
