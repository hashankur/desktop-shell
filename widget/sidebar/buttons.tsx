import icons from "@/util/icons";
import { type Variable } from "astal";
import { Gtk } from "astal/gtk4";

type StackBtn = {
  name: string;
  icon: string;
  item?: any;
  currentView: Variable<string>;
};

function StackBtn({ name, icon, item, currentView }: StackBtn) {
  return (
    <button
      onClicked={() => currentView.set(name)}
      cssClasses={[
        "px-5",
        "py-3",
        "bg-primary_container",
        "rounded-3xl",
        "min-h-10",
      ]}
      widthRequest={200}
    >
      <box>
        <box hexpand spacing={15}>
          <image cssClasses={["text-on_primary_container"]} iconName={icon} />
          <box vertical valign={Gtk.Align.CENTER} hexpand>
            <label
              label={name}
              cssClasses={["text-on_primary_container", "text-lg"]}
              xalign={0}
            />
            {item && (
              <label
                label={item}
                cssClasses={["text-on_primary_container/75", "text-sm"]}
                xalign={0}
              />
            )}
          </box>
          <image
            cssClasses={["text-on_primary_container"]}
            iconName={icons.ui.arrow.right}
          />
        </box>
      </box>
    </button>
  );
}

type ToggleBtn = {
  name: string;
  icon: string;
  item?: any;
};

function ToggleBtn({ name, icon, item, ...props }: ToggleBtn) {
  return (
    <button
      cssClasses={[
        "px-5",
        "py-3",
        "bg-primary_container",
        "rounded-3xl",
        "min-h-10",
      ]}
      widthRequest={200}
      {...props}
    >
      <box>
        <box hexpand spacing={15}>
          <image cssClasses={["text-on_primary_container"]} iconName={icon} />
          <box vertical valign={Gtk.Align.CENTER} hexpand>
            <label
              label={name}
              cssClasses={["text-on_primary_container", "text-lg"]}
              xalign={0}
            />
            {item && (
              <label
                label={item}
                cssClasses={["text-on_primary_container/75", "text-sm"]}
                xalign={0}
              />
            )}
          </box>
        </box>
      </box>
    </button>
  );
}

type BackButton = {
  name: string;
  currentView: Variable<string>;
};

function BackButton({ name, currentView }: BackButton) {
  return (
    <button hexpand onClicked={() => currentView.set("main")}>
      <box>
        <image cssClasses={["p-3"]} iconName={icons.ui.arrow.left} />
        <label cssClasses={["text-2xl"]} label={name} />
      </box>
    </button>
  );
}

export { StackBtn, ToggleBtn, BackButton };
