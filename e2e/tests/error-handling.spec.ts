import { test, expect } from "@playwright/test";

test.describe("Error Handling & Edge Cases", () => {
  test("unknown route returns 404", async ({ request }) => {
    const resp = await request.get("/api/this-route-does-not-exist");
    expect(resp.status()).toBe(404);
  });

  test("POST to GET-only endpoint returns 405", async ({ request }) => {
    const resp = await request.post("/health");
    expect(resp.status()).toBe(405);
  });

  test("malformed JSON body returns 400-level error", async ({ request }) => {
    const resp = await request.post("/api/license/validate", {
      headers: { "Content-Type": "application/json" },
      data: "this is not json{{{",
    });

    // Should be 4xx, not 500
    expect(resp.status()).toBeGreaterThanOrEqual(400);
    expect(resp.status()).toBeLessThan(500);
  });

  test("CORS preflight (OPTIONS) on /health succeeds", async ({ request }) => {
    const resp = await request.fetch("/health", {
      method: "OPTIONS",
      headers: {
        Origin: "http://localhost:3000",
        "Access-Control-Request-Method": "GET",
      },
    });

    // Permissive CORS in dev mode should accept any origin
    expect(resp.status()).toBeLessThan(400);
  });

  test("very long Authorization header does not crash server", async ({
    request,
  }) => {
    const longToken = "Bearer " + "a".repeat(10_000);
    const resp = await request.get("/super-admin/orgs", {
      headers: { Authorization: longToken },
    });

    // Should reject gracefully, not crash
    expect(resp.status()).toBe(401);
  });

  test("concurrent requests to /health all succeed", async ({ request }) => {
    const promises = Array.from({ length: 20 }, () => request.get("/health"));
    const responses = await Promise.all(promises);

    for (const resp of responses) {
      expect(resp.status()).toBe(200);
    }
  });
});
