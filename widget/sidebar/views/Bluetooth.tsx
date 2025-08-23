import AstalBluetooth from "gi://AstalBluetooth";
import type { Setter } from "ags";
import { For } from "ags";
import { createBinding } from "ags";
import { Gtk } from "ags/gtk4";
import { StackPage } from "../stack";

type BluetoothPageProps = {
  setCurrentView: Setter<string>;
};

function BluetoothPage({ setCurrentView }: BluetoothPageProps) {
  const bluetooth = AstalBluetooth.get_default();
  const devices = createBinding(bluetooth, "devices")

  return (
    <StackPage $type="named" name="Bluetooth" setCurrentView={setCurrentView}>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
        <For each={devices}>
        {(device) =>(
            <button
              class="px-5 py-2 rounded-lg hover:bg-surface_container_low"

              onClicked={() => device.connect_device().catch((err)=>print(err))}
            >
              <box spacing={15} valign={Gtk.Align.CENTER}>
                <image pixelSize={24} iconName={device.icon || ""} />
                <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER}>
                  <label
                    class="text-lg/none text-semibold"
                    label={device.name}
                    xalign={0}
                  />
                    <label
                      class="text-sm/none text-semibold"
                      label="Connected"
                      visible={device.connected}
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

export default BluetoothPage;
