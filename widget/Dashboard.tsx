import { GObject } from "astal";
import {
  App,
  Astal,
  astalify,
  ConstructProps,
  Gdk,
  Gtk,
  Widget,
} from "astal/gtk3";

class Calendar extends astalify(Gtk.Calendar) {
  static {
    GObject.registerClass(this);
  }

  constructor(
    props: ConstructProps<Gtk.Calendar, Gtk.Calendar.ConstructorProps>,
  ) {
    super(props as any);
  }
}

const WINDOW_NAME = "dashboard";

  return (
    <window
      name={WINDOW_NAME}
      application={App}
      visible={false}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.OVERLAY}
      vexpand={true}
      anchor={Astal.WindowAnchor.TOP}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          if (self.visible) {
            self.visible = false;
          }
        }
      }}
    >
      <box className="Media base">
        <box className="Media-Container" vertical>
          <box className="Calendar">{new Calendar({ vexpand: true })}</box>
        </box>
      </box>
    </window>
  );
}
