import { test, expect } from "@playwright/test";
import { BOOTSTRAP_KEY, apiKeyHeader, createTestOrg } from "./helpers";

test.describe("Super Admin — License Key Management", () => {
  test("GET /super-admin/license-keys lists all license keys", async ({
    request,
  }) => {
    const resp = await request.get("/super-admin/license-keys", {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    if (resp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(Array.isArray(body)).toBe(true);
  });

  test("POST /super-admin/license-keys generates a key for an org", async ({
    request,
  }) => {
    // First create an org
    const { resp: orgResp, slug } = await createTestOrg(
      request,
      BOOTSTRAP_KEY
    );
    if (orgResp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    const resp = await request.post("/super-admin/license-keys", {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
      data: {
        orgSlug: slug,
        seats: 25,
        plan: "enterprise",
      },
    });

    expect(resp.status()).toBe(201);
    const body = await resp.json();
    expect(body).toHaveProperty("key");
    expect(body.key).toMatch(/^lic_/);
    expect(body.seats).toBe(25);
  });

  test("POST /super-admin/license-keys returns 404 for unknown org", async ({
    request,
  }) => {
    const resp = await request.post("/super-admin/license-keys", {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
      data: {
        orgSlug: "nonexistent-org-slug-12345",
        seats: 5,
      },
    });

    if (resp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    expect(resp.status()).toBe(404);
  });

  test("DELETE /super-admin/license-keys/:key revokes a key", async ({
    request,
  }) => {
    // Create an org and generate a license key
    const { resp: orgResp, slug } = await createTestOrg(
      request,
      BOOTSTRAP_KEY
    );
    if (orgResp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    const genResp = await request.post("/super-admin/license-keys", {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
      data: { orgSlug: slug, seats: 5 },
    });
    const { key } = await genResp.json();

    // Revoke it
    const revokeResp = await request.delete(
      `/super-admin/license-keys/${encodeURIComponent(key)}`,
      {
        headers: apiKeyHeader(BOOTSTRAP_KEY),
      }
    );

    expect(revokeResp.status()).toBe(200);
    const body = await revokeResp.json();
    expect(body.ok).toBe(true);

    // Validate the revoked key — should fail
    const validateResp = await request.post("/api/license/validate", {
      data: { key, seatCount: 1 },
    });
    expect(validateResp.status()).toBe(404);
    const validateBody = await validateResp.json();
    expect(validateBody.valid).toBe(false);
  });

  test("DELETE /super-admin/license-keys/:key returns 404 for unknown key", async ({
    request,
  }) => {
    const resp = await request.delete(
      "/super-admin/license-keys/lic_nonexistent_key",
      {
        headers: apiKeyHeader(BOOTSTRAP_KEY),
      }
    );

    if (resp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    expect(resp.status()).toBe(404);
  });
});
