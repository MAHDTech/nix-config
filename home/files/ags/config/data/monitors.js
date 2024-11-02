// Returns the number of monitors.
// Each monitor has a unique index starting from 0.
// For example if there are 2 monitors, the list will be [0, 1].
export const DataMonitors = () => {
  const display = imports.gi.Gdk.Display.get_default();
  if (!display) return [];
  const n = display.get_n_monitors();
  return Array.from({ length: n }, (_, i) => i);
};
