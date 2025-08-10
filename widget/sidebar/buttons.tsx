import icons from "@/constants/icons";
import type { Accessor } from "ags";
import type { Setter } from "ags";
import { Gtk } from "ags/gtk4";
import Pango from "gi://Pango";

type StackBtnProps = {
  name: string;
  icon: string;
  item?: string;
  setCurrentView: Setter<string>;
};

function StackBtn({ name, icon, item, setCurrentView }: StackBtnProps) {
  return (
    <button
      onClicked={() => setCurrentView(name)}
      class="px-5 py-3 bg-primary_container rounded-3xl min-h-10"
      widthRequest={200}
    >
      <box>
        <box hexpand spacing={15}>
          <image class="text-on_primary_container" iconName={icon} />
          <box
            orientation={Gtk.Orientation.VERTICAL}
            valign={Gtk.Align.CENTER}
            hexpand
          >
            <label
              label={name}
              class="text-on_primary_container text-lg/none"
              xalign={0}
            />
            {item && (
              <label
                label={item}
                class="text-on_primary_container/75 text-sm/none"
                xalign={0}
                maxWidthChars={10}
                ellipsize={Pango.EllipsizeMode.END}
              />
            )}
          </box>
          <image
            class="text-on_primary_container"
            iconName={icons.ui.arrow.right}
          />
        </box>
      </box>
    </button>
  );
}

type ToggleBtnProps = {
  name: string;
  icon: string;
  item?: string;
};

function ToggleBtn({ name, icon, item, ...props }: ToggleBtnProps) {
  return (
    <button
      class="px-5 py-3 bg-primary_container rounded-3xl min-h-10"
      widthRequest={200}
      {...props}
    >
      <box>
        <box hexpand spacing={15}>
          <image class="text-on_primary_container" iconName={icon} />
          <box
            orientation={Gtk.Orientation.VERTICAL}
            valign={Gtk.Align.CENTER}
            hexpand
          >
            <label
              label={name}
              class="text-on_primary_container text-lg/none"
              xalign={0}
            />
            {item && (
              <label
                label={item}
                class="text-on_primary_container/75 text-sm/none"
                xalign={0}
              />
            )}
          </box>
        </box>
      </box>
    </button>
  );
}

type BackButtonProps = {
  name: string;
  setCurrentView: Setter<string>;
};

function BackButton({ name, setCurrentView }: BackButtonProps) {
  return (
    <button hexpand onClicked={() => setCurrentView("main")}>
      <box>
        <image class="p-3" iconName={icons.ui.arrow.left} />
        <label class="text-2xl" label={name} />
      </box>
    </button>
  );
}

export { StackBtn, ToggleBtn, BackButton };
