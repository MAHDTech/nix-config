/* Services */

const hyprland = await Service.import("hyprland");

/* Widgets */

export function WidgetClientTitle() {
  return Widget.Label({
    class_name: "client-title",
    label: hyprland.active.client.bind("title"),
  });
}
