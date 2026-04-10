import { test, expect } from "@playwright/test";

test.describe("Health Check", () => {
  test("GET /health returns 200 with status ok", async ({ request }) => {
    const resp = await request.get("/health");

    expect(resp.status()).toBe(200);

    const body = await resp.json();
    expect(body.status).toBe("ok");
    expect(body).toHaveProperty("oauth");
  });

  test("GET /health response is fast (< 2s)", async ({ request }) => {
    const start = Date.now();
    const resp = await request.get("/health");
    const elapsed = Date.now() - start;

    expect(resp.status()).toBe(200);
    expect(elapsed).toBeLessThan(2000);
  });
});
