// Astal.
import { App, Widget } from "astal/gtk3";

// Styles.
import style from "./style/style.scss";

// Widgets.
//import Applauncher from "./widget/Applauncher";
import Bar from "./widget/Bar";
//import MprisPlayers from "./widget/MediaPlayer";
//import NotificationPopups from "./widget/NotificationPopups";

App.start({
  css: style,
  instanceName: "ags",
  requestHandler(request, res) {
    print(request);
    res("ok");
  },
  main: () => {
    // Initialize bar on all monitors
    App.get_monitors().map(Bar);

    // Initialize applauncher
    //Applauncher();

    // Initialize media player
    //new Widget.Window({}, MprisPlayers());

    // Initialize notification popups on all monitors
    //App.get_monitors().map(NotificationPopups);
  },
});
