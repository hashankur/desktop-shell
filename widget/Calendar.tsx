import Window from "@/common/window";
import { Astal, Gtk } from "astal/gtk4";

const WINDOW_NAME = "calendar";

export default function Calendar() {
  return (
    <Window name={WINDOW_NAME} anchor={Astal.WindowAnchor.TOP}>
      <box
        cssClasses={["p-5", "bg-base", "min-w-72", "min-h-52", "rounded-xl"]}
      >
        <Gtk.Calendar hexpand />
      </box>
    </Window>
  );
}
