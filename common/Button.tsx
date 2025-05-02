import type { ButtonProps } from "astal/gtk4/widget";

export default function Button({ child, ...props }: ButtonProps) {
  return (
    <button
      cssClasses={[
        "rounded-lg",
        "bg-surface_container_lowest",
        "hover:bg-surface_container_low",
        "px-3",
      ]}
      {...props}
    >
      {child}
    </button>
  );
}
