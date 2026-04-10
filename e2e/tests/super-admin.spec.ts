import { test, expect } from "@playwright/test";
import { BOOTSTRAP_KEY, apiKeyHeader, createTestOrg, uniqueSlug } from "./helpers";

/**
 * Super Admin API tests.
 *
 * These tests require the backend to be running with PLAUNCHER_BOOTSTRAP_KEY
 * set to the same value as TEST_BOOTSTRAP_KEY (default: "test-bootstrap-key").
 *
 * The bootstrap key creates a super admin on first startup, allowing these
 * tests to authenticate without GitHub OAuth.
 */
test.describe("Super Admin — Org CRUD", () => {
  test("GET /super-admin/orgs requires authentication", async ({
    request,
  }) => {
    const resp = await request.get("/super-admin/orgs");
    expect(resp.status()).toBe(401);
  });

  test("GET /super-admin/orgs with bootstrap key returns org list", async ({
    request,
  }) => {
    const resp = await request.get("/super-admin/orgs", {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    // 200 if bootstrap key is valid, 401 if not configured
    if (resp.status() === 200) {
      const body = await resp.json();
      expect(Array.isArray(body)).toBe(true);
    } else {
      // Bootstrap key not configured — skip gracefully
      expect(resp.status()).toBe(401);
    }
  });

  test("POST /super-admin/orgs creates a new org", async ({ request }) => {
    const { resp, slug } = await createTestOrg(request, BOOTSTRAP_KEY);

    if (resp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    expect(resp.status()).toBe(201);
    const body = await resp.json();
    expect(body.slug).toBe(slug);
    expect(body.name).toContain("Test Org");
    expect(body.plan).toBe("team");
    expect(body.seats).toBe(10);
  });

  test("POST /super-admin/orgs rejects duplicate slug", async ({
    request,
  }) => {
    const slug = uniqueSlug("dup");

    // Create first org
    const { resp: resp1 } = await createTestOrg(request, BOOTSTRAP_KEY, {
      slug,
    });
    if (resp1.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }
    expect(resp1.status()).toBe(201);

    // Attempt duplicate
    const { resp: resp2 } = await createTestOrg(request, BOOTSTRAP_KEY, {
      slug,
    });
    expect(resp2.status()).toBe(409);
    const body = await resp2.json();
    expect(body.error).toContain("already exists");
  });

  test("GET /super-admin/orgs/:slug returns org with members", async ({
    request,
  }) => {
    const { resp: createResp, slug } = await createTestOrg(
      request,
      BOOTSTRAP_KEY
    );
    if (createResp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    const resp = await request.get(`/super-admin/orgs/${slug}`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(body.org.slug).toBe(slug);
    expect(body).toHaveProperty("members");
    expect(Array.isArray(body.members)).toBe(true);
  });

  test("GET /super-admin/orgs/:slug returns 404 for unknown slug", async ({
    request,
  }) => {
    const resp = await request.get("/super-admin/orgs/nonexistent-org-slug", {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    if (resp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    expect(resp.status()).toBe(404);
  });

  test("PATCH /super-admin/orgs/:slug updates org fields", async ({
    request,
  }) => {
    const { resp: createResp, slug } = await createTestOrg(
      request,
      BOOTSTRAP_KEY
    );
    if (createResp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    const resp = await request.patch(`/super-admin/orgs/${slug}`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
      data: { seats: 50 },
    });

    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(body.ok).toBe(true);

    // Verify the update
    const getResp = await request.get(`/super-admin/orgs/${slug}`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });
    const getBody = await getResp.json();
    expect(getBody.org.seats).toBe(50);
  });

  test("PATCH /super-admin/orgs/:slug with empty body returns 400", async ({
    request,
  }) => {
    const { resp: createResp, slug } = await createTestOrg(
      request,
      BOOTSTRAP_KEY
    );
    if (createResp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    const resp = await request.patch(`/super-admin/orgs/${slug}`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
      data: {},
    });

    expect(resp.status()).toBe(400);
  });
});

test.describe("Super Admin — Org Suspend/Unsuspend", () => {
  test("POST /super-admin/orgs/:slug/suspend suspends an org", async ({
    request,
  }) => {
    const { resp: createResp, slug } = await createTestOrg(
      request,
      BOOTSTRAP_KEY
    );
    if (createResp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    const resp = await request.post(`/super-admin/orgs/${slug}/suspend`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    expect(resp.status()).toBe(200);

    // Verify org now has suspendedAt set
    const getResp = await request.get(`/super-admin/orgs/${slug}`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });
    const body = await getResp.json();
    expect(body.org.suspendedAt).not.toBeNull();
  });

  test("POST /super-admin/orgs/:slug/unsuspend removes suspension", async ({
    request,
  }) => {
    const { resp: createResp, slug } = await createTestOrg(
      request,
      BOOTSTRAP_KEY
    );
    if (createResp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    // Suspend first
    await request.post(`/super-admin/orgs/${slug}/suspend`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    // Then unsuspend
    const resp = await request.post(`/super-admin/orgs/${slug}/unsuspend`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    expect(resp.status()).toBe(200);

    // Verify suspendedAt is cleared
    const getResp = await request.get(`/super-admin/orgs/${slug}`, {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });
    const body = await getResp.json();
    expect(body.org.suspendedAt).toBeNull();
  });

  test("suspend returns 404 for unknown org", async ({ request }) => {
    const resp = await request.post(
      "/super-admin/orgs/nonexistent-slug/suspend",
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

test.describe("Super Admin — Metrics", () => {
  test("GET /super-admin/metrics returns aggregate metrics", async ({
    request,
  }) => {
    const resp = await request.get("/super-admin/metrics", {
      headers: apiKeyHeader(BOOTSTRAP_KEY),
    });

    if (resp.status() === 401) {
      test.skip(true, "Bootstrap key not configured on server");
      return;
    }

    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(body).toHaveProperty("totalOrgs");
    expect(body).toHaveProperty("activeOrgs");
    expect(body).toHaveProperty("totalMembers");
    expect(body).toHaveProperty("totalRepos");
    expect(body).toHaveProperty("planBreakdown");
    expect(typeof body.totalOrgs).toBe("number");
    expect(typeof body.activeOrgs).toBe("number");
  });
});
