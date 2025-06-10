import AstalBluetooth from "gi://AstalBluetooth";
import { StackPage } from "../stack";
import { bind, type Variable } from "astal";
import { Gtk } from "astal/gtk4";

type BluetoothPage = {
  currentView: Variable<string>;
};

function BluetoothPage({ currentView }: BluetoothPage) {
  const bluetooth = AstalBluetooth.get_default();

  return (
    <StackPage name="Bluetooth" currentView={currentView}>
      <box vertical spacing={5}>
        {bind(bluetooth, "devices").as((device) =>
          device.map((device) => (
            <button
              cssClasses={[
                "px-5",
                "py-2",
                "rounded-lg",
                "hover:bg-surface_container_low",
              ]}
              onClicked={() => print(device.connect_device())}
            >
              <box spacing={15} valign={Gtk.Align.CENTER}>
                <image cssClasses={["icon-lg"]} iconName={device.icon || ""} />
                <box vertical valign={Gtk.Align.CENTER}>
                  <label
                    cssClasses={["text-lg", "text-semibold"]}
                    label={device.name}
                    xalign={0}
                  />
                  {device.connected && (
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

export default BluetoothPage;
