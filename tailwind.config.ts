import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#eef7f1",
          100: "#d6ecde",
          200: "#aedabf",
          500: "#1f7a4d",
          600: "#17663f",
          700: "#0f5132",
          800: "#0b3d26",
          900: "#082d1c",
        },
        gold: "#d9a441",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
        serif: ["Playfair Display", "Georgia", "serif"],
        urdu: ["Noto Nastaliq Urdu", "serif"],
      },
    },
  },
  plugins: [],
};

export default config;
