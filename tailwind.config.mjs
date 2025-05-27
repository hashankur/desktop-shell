/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./widget/**/*.tsx", "./common/**/*.tsx"],
  theme: {
    fontSize: {
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
        ...require("./util/colors.json").colors.dark,
      },
    },
  },
  plugins: [
    //  function ({ addComponents, theme }) {
    //   const paddingClasses = {};
    //   for (const [size, value] of Object.entries(theme('spacing'))) {
    //     paddingClasses[`.p-${size}`] = { padding: value };
    //     paddingClasses[`.px-${size}`] = { 'padding-left': value, 'padding-right': value };
    //     paddingClasses[`.py-${size}`] = { 'padding-top': value, 'padding-bottom': value };
    //   }
    //   addComponents(paddingClasses);
    // },
  ],
};

