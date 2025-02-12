import { App } from "astal/gtk4";

export function hideWindow(name: string) {
  App.get_window(name)?.set_visible(false);
}
