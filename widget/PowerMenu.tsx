import icons from "@/utils/icons";
import { exec } from "astal";
import { App, Astal, Gdk } from "astal/gtk3";

const WINDOW_NAME = "power-menu";

const options = [
  {
    name: "Shutdown",
    icon: icons.powermenu.shutdown,
    command: "systemctl poweroff",
  },
  {
    name: "Reboot",
    icon: icons.powermenu.reboot,
    command: "systemctl reboot",
  },
  {
    name: "Suspend",
    icon: icons.powermenu.sleep,
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
