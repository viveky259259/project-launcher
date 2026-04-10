import { defineConfig } from "@playwright/test";

/**
 * Playwright configuration for plauncher-backend API E2E tests.
 *
 * Prerequisites:
 *   1. Backend running at BASE_URL (default http://localhost:8743)
 *   2. MongoDB reachable by the backend
 *
 * Environment variables:
 *   BASE_URL              — Backend base URL (default: http://localhost:8743)
 *   TEST_BOOTSTRAP_KEY    — Bootstrap API key for super admin tests
 *   TEST_JWT_SECRET        — JWT secret matching the running backend (default: dev-secret-change-me)
 */
export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  retries: 0,
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:8743",
    extraHTTPHeaders: {
      Accept: "application/json",
    },
  },
  reporter: [["list"], ["html", { open: "never" }]],
});
