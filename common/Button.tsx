import type { CCProps } from "ags";
import type { Gtk } from "ags/gtk4";

type Props = CCProps<Gtk.Button, Gtk.Button.ConstructorProps> & {
  child?: JSX.Element | Array<JSX.Element>;
};

export default function Button({ children, ...props }: Props) {
  return (
    <button
      class="rounded-lg bg-surface_container_lowest hover:bg-surface_container_low px-3"
      {...props}
    >
      {children}
    </button>
  );
}
