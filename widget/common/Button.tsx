type ButtonProps = JSX.IntrinsicElements["button"] & {
  child?: JSX.Element | Array<JSX.Element>;
};

export default function Button({ children, ...props }: ButtonProps) {
  return (
    <button
      class="rounded-lg bg-surface_container_lowest hover:bg-surface_container_low px-3"
      {...props}
    >
      {children}
    </button>
  );
}
