import { bind, execAsync, type Variable } from "astal";
import Network from "gi://AstalNetwork";
import { StackPage } from "@/widget/sidebar/stack";
import { Gtk } from "astal/gtk4";

type NetworkPage = {
  currentView: Variable<string>;
};

function NetworkPage({ currentView }: NetworkPage) {
  const network = Network.get_default().wifi;
  const connected = bind(network, "activeAccessPoint");

  return (
    <StackPage name="Network" toggle={network} currentView={currentView}>
      <box vertical spacing={5}>
        {bind(network, "accessPoints").as((ap) =>
          ap
            .filter((ap) => !!ap.ssid)
            .sort((a, b) => b.strength - a.strength)
            .map((ap) => (
              <button
                cssClasses={[
                  "px-5",
                  "py-2",
                  "rounded-lg",
                  "hover:bg-surface_container_low",
                ]}
                onClicked={() =>
                  execAsync(`nmcli device wifi connect ${ap.bssid}`)
                }
              >
                <box spacing={15} valign={Gtk.Align.CENTER}>
                  <image
                    cssClasses={["icon-lg"]}
                    iconName={ap.iconName || ""}
                  />
                  <box vertical valign={Gtk.Align.CENTER}>
                    <label
                      cssClasses={["text-lg", "text-semibold"]}
                      label={ap.ssid}
                      xalign={0}
                    />
                    {connected?.get().ssid == ap.ssid && (
                      <label
                        cssClasses={["text-sm", "text-semibold"]}
                        label="Connected"
                      />
                    )}
                  </box>
                </box>
              </button>
            )),
        )}
      </box>
    </StackPage>
  );
}

export default NetworkPage;
