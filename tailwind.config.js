/** @type {import('tailwindcss').Config} */
import resolveConfig from "tailwindcss/resolveConfig";
import defaultConfig from "tailwindcss/defaultConfig";

const config = resolveConfig(defaultConfig);
module.exports = {
    content: ["./widget/**/*.tsx"],
    theme: {
        fontSize: {
            // Remove line height
            lg: ["1.125rem"],
            xl: ["1.25rem"],
            "2xl": ["1.5rem"],
            "4xl": ["2.25rem"],
        },
        extend: {
            colors: {
                base: "#0b0e14"
            }
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
