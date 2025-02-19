import { ButtonProps } from "astal/gtk4/widget";

export default function Button({ child, ...props }: ButtonProps) {
  return (
    <button cssClasses={["rounded-lg", "hover:bg-base1", "px-3"]} {...props}>
      {child}
    </button>
  );
}
