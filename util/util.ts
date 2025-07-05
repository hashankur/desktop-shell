import app from "ags/gtk4/app";

function hideWindow(name: string) {
  app.get_window(name)?.set_visible(false);
}

export default { hideWindow };
