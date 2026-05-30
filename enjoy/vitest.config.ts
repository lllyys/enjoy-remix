import path from "path";
import { defineConfig } from "vitest/config";

// Self-contained Vitest config (does NOT import vite.renderer.config.ts,
// which expects Electron Forge env). Path aliases mirror the Vite setup.
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@renderer": path.resolve(__dirname, "./src/renderer"),
      "@commands": path.resolve(__dirname, "./src/commands"),
    },
  },
  test: {
    // Default Node environment; component tests opt into jsdom per-file later.
    environment: "node",
    include: ["src/**/*.{test,spec}.{ts,tsx}"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary", "html"],
      reportsDirectory: "coverage",
      include: ["src/**/*.{ts,tsx}"],
      exclude: [
        "src/**/*.d.ts",
        "src/types/**",
        "src/main/db/migrations/**",
        "**/*.config.*",
        "src/**/*.{test,spec}.*",
      ],
    },
  },
});
