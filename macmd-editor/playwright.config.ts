import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  expect: { timeout: 5_000 },
  retries: 0,
  projects: [
    {
      name: "webkit",
      use: { browserName: "webkit" },
    },
  ],
});
