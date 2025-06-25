import Window from "@/common/window";
import { createBinding, createState, For, onCleanup } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import AstalNotifd from "gi://AstalNotifd";
import Notification from "./Notification";

export default function NotificationPopups() {
  const monitors = createBinding(app, "monitors");

  const notifd = AstalNotifd.get_default();

  const [notifications, setNotifications] = createState(
    new Array<AstalNotifd.Notification>(),
  );

  const notifiedHandler = notifd.connect("notified", (_, id, replaced) => {
    const notification = notifd.get_notification(id);

    if (replaced && notifications.get().some((n) => n.id === id)) {
      setNotifications((ns) => ns.map((n) => (n.id === id ? notification : n)));
    } else {
      setNotifications((ns) => [notification, ...ns]);
    }
  });

  const resolvedHandler = notifd.connect("resolved", (_, id) => {
    setNotifications((ns) => ns.filter((n) => n.id !== id));
  });

  // technically, we don't need to cleanup because in this example this is a root component
  // and this cleanup function is only called when the program exits, but exiting will cleanup either way
  // but it's here to remind you that you should not forget to cleanup signal connections
  onCleanup(() => {
    notifd.disconnect(notifiedHandler);
    notifd.disconnect(resolvedHandler);
  });

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
                  notification={notification}
                  onHoverLost={() =>
                    setNotifications((ns) =>
                      ns.filter((n) => n.id !== notification.id),
                    )
                  }
                />
              )}
            </For>
          </box>
        </Window>
      )}
    </For>
  );
}
