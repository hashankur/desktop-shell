import Window from "@/common/window";
import icons from "@/util/icons";
import { exec } from "astal";
import { App } from "astal/gtk3";

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
    <Window name={WINDOW_NAME}>
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
    </Window>
  );
}
