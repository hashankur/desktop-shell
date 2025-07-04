import Window from "@/common/window";
import { createBinding, createState, For, onCleanup } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import AstalNotifd from "gi://AstalNotifd";
import Notification from "./Notification";
import { useNotificationHandler } from "@/util/notification";
import { timeout } from "ags/time";

export default function NotificationPopups() {
  const monitors = createBinding(app, "monitors");

  const notifd = AstalNotifd.get_default();

  const [notifications, setNotifications] = createState(
    new Array<AstalNotifd.Notification>(),
  );

  onCleanup(useNotificationHandler(notifd, notifications, setNotifications));

  const dismiss = (notification: AstalNotifd.Notification) => {
    setNotifications((ns) => ns.filter((n) => n.id !== notification.id));
  };

  return (
    <For each={monitors} cleanup={(win) => (win as Gtk.Window).destroy()}>
      {(monitor) => (
        <Window
          namespace="astal-notifications"
          gdkmonitor={monitor}
          keymode={Astal.Keymode.NONE}
          visible={notifications((ns) => ns.length > 0)}
          anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
        >
          <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <For each={notifications}>
              {(notification) => (
                <Notification
                  $={() => timeout(5000, () => dismiss(notification))}
                  notification={notification}
                  onHoverLost={() => dismiss(notification)}
                />
              )}
            </For>
          </box>
        </Window>
      )}
    </For>
  );
}
