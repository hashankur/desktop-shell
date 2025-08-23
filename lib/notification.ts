import type { Setter } from "ags";
import type { Accessor } from "ags";
import type AstalNotifd from "gi://AstalNotifd";

export function useNotificationHandler(
  notifd: AstalNotifd.Notifd,
  notifications: Accessor<AstalNotifd.Notification[]>,
  setNotifications: Setter<AstalNotifd.Notification[]>,
) {
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
  return () => {
    notifd.disconnect(notifiedHandler);
    notifd.disconnect(resolvedHandler);
  };
}
