import Network from "gi://AstalNetwork";
import { StackPage } from "@/widget/sidebar/stack";
import type { Accessor } from "ags";
import type { Setter } from "ags";
import { For, createBinding, createComputed } from "ags";
import { Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";

type NetworkPageProps = {
  setCurrentView: Setter<string>;
};

export default function NetworkPage({ setCurrentView }: NetworkPageProps) {
  const network = Network.get_default().wifi;
  const connectedNetwork = createBinding(
    network,
    "activeAccessPoint",
  )((v) => v?.ssid ?? "");
  const accessPoints = createBinding(network, "accessPoints").as((aps) => {
    const uniqueAccessPoints = new Map<string, (typeof aps)[number]>();
    // biome-ignore lint/complexity/noForEach: <explanation>
    aps
      .filter((ap) => !!ap.ssid)
      .forEach((ap) => {
        const existingAp = uniqueAccessPoints.get(ap.ssid);
        if (!existingAp || existingAp.strength < ap.strength) {
          uniqueAccessPoints.set(ap.ssid, ap);
        }
      });
    return Array.from(uniqueAccessPoints.values()).sort(
      (a, b) => b.strength - a.strength,
    );
  });

  return (
    <StackPage name="Network" toggle={network} setCurrentView={setCurrentView}>
      <box
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
        vexpand
        homogeneous
      >
        <For each={accessPoints}>
          {(ap) => (
            <button
              class="px-5 py-2 rounded-lg hover:bg-surface_container_low"
              onClicked={() =>
                execAsync(`nmcli device wifi connect ${ap.bssid}`)
              }
            >
              <box spacing={20} valign={Gtk.Align.CENTER}>
                <image pixelSize={24} iconName={ap.iconName || ""} />
                <box
                  orientation={Gtk.Orientation.VERTICAL}
                  valign={Gtk.Align.CENTER}
                >
                  <label
                    class="text-lg/none text-semibold"
                    label={ap.ssid}
                    xalign={0}
                  />
                  <label
                    class="text-sm/none text-semibold"
                    label="Connected"
                    xalign={0}
                    visible={connectedNetwork((v) => v === ap.ssid)}
                  />
                </box>
              </box>
            </button>
          )}
        </For>
      </box>
    </StackPage>
  );
}
