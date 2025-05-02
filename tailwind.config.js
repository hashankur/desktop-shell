/** @type {import('tailwindcss').Config} */
import resolveConfig from "tailwindcss/resolveConfig";
import defaultConfig from "tailwindcss/defaultConfig";

import generatedColors from "./util/colors.json";

const config = resolveConfig(defaultConfig);
module.exports = {
  content: ["./widget/**/*.tsx", "./common/**/*.tsx"],
  theme: {
    fontSize: {
      // Remove line height
      sm: ["0.875rem"],
      lg: ["1.125rem"],
      xl: ["1.25rem"],
      "2xl": ["1.5rem"],
      "3xl": ["1.875rem"],
      "4xl": ["2.25rem"],
      "5xl": ["3rem"],
    },
    extend: {
      colors: {
        ...generatedColors.colors.dark,
      },
    },
  },
  plugins: [],
  // disable stuff with properties that don't work
  corePlugins: {
    preflight: false,
    visibility: false,
    display: false,
    overflow: false,
    whitespace: false,
    transform: false,
    textOverflow: false,
    position: false,
    lineHeight: false,
    ...[
      Object.fromEntries(
        Object.keys(config.corePlugins)
          .filter((k) => k.startsWith("backdrop") || k.startsWith("flex"))
          .map((k) => [k, false]),
      ),
    ],
  },
};
