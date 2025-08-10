/** @type {import('tailwindcss').Config} */
import resolveConfig from "tailwindcss/resolveConfig";
import defaultConfig from "tailwindcss/defaultConfig";

import generatedColors from "./constants/colors.json";

const config = resolveConfig(defaultConfig);
module.exports = {
  content: ["./widget/**/*.tsx", "./common/**/*.tsx"],
  theme: {
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
