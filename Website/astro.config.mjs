import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://modern-swift-dev.github.io/skein-swift/",
  base: "/skein-swift",
  integrations: [],
  vite: {
    plugins: [tailwindcss()]
  }
});
