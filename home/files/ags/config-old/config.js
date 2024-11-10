import GLib from "gi://GLib";

// $XDG_RUNTIME_DIR/ags/run.js
const main = `${GLib.get_user_runtime_dir()}/ags/run.js`;

console.log(`Compiling main.ts to ${main}`);

try {
  await Utils.execAsync(["bun", "build", `${App.configDir}/main.ts`, "--outfile", main, "--external", "resource://*", "--external", "gi://*", "--external", "file://*"]);

  await import(`file://${main}`);
} catch (error) {
  console.error(error);

  App.quit();
}
