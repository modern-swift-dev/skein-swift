import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://modern-swift-dev.github.io/docs/skein-swift/",
  base: "/docs/skein-swift",
  integrations: [],
  vite: {
    plugins: [tailwindcss()]
  }
});
