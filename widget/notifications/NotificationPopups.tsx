import AstalNotifd from "gi://AstalNotifd";
import Window from "@/common/window";
import { timeout } from "astal";
import { App, Astal, type Gdk, hook } from "astal/gtk4";
import Notification from "./Notification";

export default function NotificationPopup(gdkmonitor: Gdk.Monitor) {
  const { TOP, RIGHT } = Astal.WindowAnchor;
  const notifd = AstalNotifd.get_default();

  return (
    <Window
      setup={(self) => {
        const notificationQueue: number[] = [];
        let isProcessing = false;

        hook(self, notifd, "notified", (_, id: number) => {
          if (
            notifd.dont_disturb &&
            notifd.get_notification(id).urgency !== AstalNotifd.Urgency.CRITICAL
          ) {
            return;
          }
          notificationQueue.push(id);
          processQueue();
        });

        hook(self, notifd, "resolved", (_, __) => {
          self.visible = false;
          isProcessing = false;
          timeout(300, () => {
            processQueue();
          });
        });

        function processQueue() {
          if (isProcessing || notificationQueue.length === 0) return;
          isProcessing = true;
          const id = notificationQueue.shift();

          self.set_child(
            <box vertical>
              {Notification({ n: notifd.get_notification(id!) })}
            </box>,
          );
          self.visible = true;

          timeout(5000, () => {
            self.visible = false;
            isProcessing = false;
            self.set_child(null);
            timeout(300, () => {
              processQueue();
            });
          });
        }
      }}
      namespace={"astal-notifications"}
      gdkmonitor={gdkmonitor}
      anchor={TOP | RIGHT}
      margin={10}
      keymode={Astal.Keymode.NONE}
    />
  );
}
