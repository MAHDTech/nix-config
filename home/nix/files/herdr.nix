{ _ }:
{
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    #########################
    # Theme
    #########################
    [theme]
    name = "vesper"
    auto_switch = false

    # Cyberpunk custom accent overrides
    [theme.custom]
    sidebar_bg = "#0F0A18"
    active_row_bg = "#312447"
    selection_bg = "#591E4E"
    panel_bg = "reset"
    accent = "#36F9F6"
    green = "#72F1B8"
    blue = "#2EE2FA"
    red = "#FE4450"
    yellow = "#FDF129"

    #########################
    # UI & Notifications
    #########################
    [ui]
    status_indicators = "symbols"
    show_agent_labels_on_pane_borders = true
    agent_panel_sort = "spaces"

    [ui.toast]
    delivery = "system"

    #########################
    # Keybindings
    #########################
    [keys]
    prefix = "ctrl+b"

    # Tab management (Browser/Ghostty muscle memory)
    new_tab = ["prefix+c", "ctrl+shift+t"]
    next_tab = ["prefix+n", "ctrl+tab"]
    previous_tab = ["prefix+p", "ctrl+shift+tab"]

    # Direct split shortcuts (Ghostty muscle memory + prefix fallback)
    split_vertical = ["prefix+v", "ctrl+shift+o"]
    split_horizontal = ["prefix+minus", "ctrl+shift+e"]

    # Pane zoom / fullscreen toggle inside Herdr
    zoom = ["prefix+z", "alt+enter"]

    # Vim directional navigation between panes
    focus_pane_left = "prefix+h"
    focus_pane_down = "prefix+j"
    focus_pane_up = "prefix+k"
    focus_pane_right = "prefix+l"

    # Vim pane swapping
    swap_pane_left = "prefix+shift+h"
    swap_pane_down = "prefix+shift+j"
    swap_pane_up = "prefix+shift+k"
    swap_pane_right = "prefix+shift+l"

    # Vi Copy Mode (h/j/k/l, v/y to select/yank, / to search)
    copy_mode = "prefix+["
  '';
}
