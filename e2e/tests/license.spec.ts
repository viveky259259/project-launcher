import { test, expect } from "@playwright/test";

test.describe("License Validation", () => {
  test("POST /api/license/validate with invalid key returns not-found", async ({
    request,
  }) => {
    const resp = await request.post("/api/license/validate", {
      data: {
        key: "lic_nonexistent_key_123",
        seatCount: 1,
        instanceId: "e2e-test",
      },
    });

    // Should be 404 (key not found), not 500
    expect(resp.status()).toBe(404);
    const body = await resp.json();
    expect(body.valid).toBe(false);
    expect(body.reason).toBeDefined();
  });

  test("POST /api/license/validate with empty key returns error", async ({
    request,
  }) => {
    const resp = await request.post("/api/license/validate", {
      data: {
        key: "",
        seatCount: 1,
      },
    });

    expect(resp.status()).toBe(404);
    const body = await resp.json();
    expect(body.valid).toBe(false);
  });

  test("POST /api/license/validate requires no auth", async ({ request }) => {
    // License validation is called by self-hosted instances with just the key
    // — no Authorization header needed
    const resp = await request.post("/api/license/validate", {
      headers: {}, // Explicitly no auth
      data: {
        key: "lic_test_key",
        seatCount: 5,
      },
    });

    // Should get a valid response (404 for unknown key), NOT 401
    expect(resp.status()).not.toBe(401);
  });
});
