import { test, expect } from "@playwright/test";

test.describe("Authentication", () => {
  // ── Missing / malformed Authorization header ─────────────────────────

  test("missing Authorization header returns 401", async ({ request }) => {
    const resp = await request.get("/super-admin/orgs", {
      headers: {},
    });

    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.error).toContain("Missing Authorization header");
  });

  test("malformed Authorization header (no Bearer prefix) returns 401", async ({
    request,
  }) => {
    const resp = await request.get("/super-admin/orgs", {
      headers: { Authorization: "Token some-random-token" },
    });

    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.error).toBeDefined();
  });

  // ── Invalid tokens ───────────────────────────────────────────────────

  test("invalid JWT returns 401", async ({ request }) => {
    const resp = await request.get("/super-admin/orgs", {
      headers: { Authorization: "Bearer not.a.valid.jwt" },
    });

    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.error).toBeDefined();
  });

  test("invalid API key (plk_ prefix) returns 401", async ({ request }) => {
    const resp = await request.get("/super-admin/orgs", {
      headers: {
        Authorization: "Bearer plk_nonexistent_key_1234567890",
      },
    });

    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.error).toBeDefined();
    // Should NOT be an internal server error — should be a clean auth rejection
    expect(body.error).not.toContain("Internal server error");
  });

  test("license key prefix (lic_) is not treated as API key", async ({
    request,
  }) => {
    const resp = await request.get("/super-admin/orgs", {
      headers: { Authorization: "Bearer lic_some_license_key_value" },
    });

    expect(resp.status()).toBe(401);
    const body = await resp.json();
    // Must NOT produce an internal server error (would indicate DB lookup)
    expect(body.error).not.toBe("Internal server error");
  });

  // ── OAuth configuration ──────────────────────────────────────────────

  test("OAuth login endpoint responds (configured or not)", async ({
    request,
  }) => {
    // When OAuth is not configured, returns 404 with helpful message.
    // When configured, returns 302 redirect to GitHub.
    const resp = await request.get("/auth/super-admin/github", {
      maxRedirects: 0,
    });

    // Either 302 (configured) or 404 (not configured) is acceptable
    expect([302, 404]).toContain(resp.status());

    if (resp.status() === 404) {
      const body = await resp.json();
      expect(body.error).toContain("GitHub OAuth not configured");
    }
  });
});
