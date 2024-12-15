import Window from "@/common/window";
import { GObject } from "astal";
import { Astal, astalify, ConstructProps, Gtk } from "astal/gtk3";

class Cal extends astalify(Gtk.Calendar) {
  static {
    GObject.registerClass(this);
  }

  constructor(
    props: ConstructProps<Gtk.Calendar, Gtk.Calendar.ConstructorProps>,
  ) {
    super(props as any);
  }
}

const WINDOW_NAME = "calendar";

export default function Calendar() {
  return (
    <Window name={WINDOW_NAME} anchor={Astal.WindowAnchor.TOP}>
      <box className="Media base">
        <box className="Calendar">{new Cal({ vexpand: true })}</box>
      </box>
    </Window>
  );
}
