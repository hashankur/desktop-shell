import Adw from "gi://Adw";
import Pango from "gi://Pango";
import icons from "@/constants/icons";
import { QS_BUTTON_WIDTH } from "@/constants/spacing";
import type { Accessor } from "ags";
import type { Setter } from "ags";
import { Gtk } from "ags/gtk4";

type StackBtnProps = {
  name: string;
  icon: string;
  item?: Accessor<string>;
  setCurrentView: Setter<string>;
};

function StackBtn({ name, icon, item, setCurrentView }: StackBtnProps) {
  return (
    <Adw.Clamp maximumSize={450 / 2}>
      <button
        onClicked={() => setCurrentView(name)}
        class="px-5 py-3 bg-primary_container rounded-3xl min-h-10"
      >
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
      </button>
    </Adw.Clamp>
  );
}

type ToggleBtnProps = {
  name: string;
  icon: string;
  item?: string;
};

function ToggleBtn({ name, icon, item, ...props }: ToggleBtnProps) {
  return (
    <Adw.Clamp maximumSize={450 / 2}>
      <button
        class="px-5 py-3 bg-primary_container rounded-3xl min-h-10"
        {...props}
      >
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
      </button>
    </Adw.Clamp>
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
        <image class="pr-3" iconName={icons.ui.arrow.left} />
        <label class="text-2xl" label={name} />
      </box>
    </button>
  );
}

export { StackBtn, ToggleBtn, BackButton };
