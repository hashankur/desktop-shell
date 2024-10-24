import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind, exec, timeout } from "astal";

const WINDOW_NAME = "power-menu";

export default function PowerMenu() {
  return (
    <window
      name={WINDOW_NAME}
      application={App}
      visible={false}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.OVERLAY}
      vexpand={true}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          if (self.visible) {
            self.visible = false;
          }
        }
      }}
    >
      <box className="base" spacing={20}>
        <button onClick={() => exec("systemctl suspend")}>
          <icon className="PowerMenu-Icon" icon="system-shutdown-symbolic" />
        </button>
        <button onClick={() => exec("systemctl suspend")}>
          <icon className="PowerMenu-Icon" icon="view-refresh-symbolic" />
        </button>
        <button onClick={() => exec("systemctl suspend")}>
          <icon
            className="PowerMenu-Icon"
            icon="preferences-desktop-screensaver-symbolic"
          />
        </button>
      </box>
    </window>
  );
}
