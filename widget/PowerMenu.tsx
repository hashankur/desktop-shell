import { App, Astal, Gdk } from "astal/gtk3";
import { exec } from "astal";

const WINDOW_NAME = "power-menu";

const options = [
  {
    name: "Shutdown",
    icon: "system-shutdown-symbolic",
    command: "systemctl poweroff",
  },
  {
    name: "Reboot",
    icon: "view-refresh-symbolic",
    command: "systemctl reboot",
  },
  {
    name: "Suspend",
    icon: "preferences-desktop-screensaver-symbolic",
    command: "systemctl suspend",
  },
];

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
      <box className="base" spacing={10}>
        {options.map((option) => (
          <button
            on_Clicked={() => {
              App.toggle_window(WINDOW_NAME);
              exec(option.command);
            }}
          >
            <icon className="PowerMenu-Icon" icon={option.icon} />
          </button>
        ))}
      </box>
    </window>
  );
}
