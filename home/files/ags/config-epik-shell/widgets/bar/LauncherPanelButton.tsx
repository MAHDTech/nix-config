import PanelButton from "../common/PanelButton"
import { WINDOW_NAME } from "../applauncher/Applauncher"
import { App } from "astal/gtk4"

export default function LauncherPanelButton() {
  return (
    <PanelButton window={WINDOW_NAME} onClicked={() => App.toggle_window(WINDOW_NAME)}>
      <image iconName="preferences-desktop-apps-symbolic" />
    </PanelButton>
  )
}
