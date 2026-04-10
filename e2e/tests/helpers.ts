import { APIRequestContext } from "@playwright/test";

/**
 * Shared helpers for plauncher E2E tests.
 */

/** Bootstrap API key — must match PLAUNCHER_BOOTSTRAP_KEY on the running server. */
export const BOOTSTRAP_KEY =
  process.env.TEST_BOOTSTRAP_KEY || "test-bootstrap-key";

/** Create an Authorization header for an API key. */
export function apiKeyHeader(key: string) {
  return { Authorization: `Bearer ${key}` };
}

/** Create an Authorization header for a JWT. */
export function jwtHeader(token: string) {
  return { Authorization: `Bearer ${token}` };
}

/** Generate a unique slug for test isolation. */
export function uniqueSlug(prefix = "e2e"): string {
  const id = Math.random().toString(36).substring(2, 8);
  return `${prefix}-${Date.now()}-${id}`;
}

/**
 * Create a test org via the super admin API.
 * Requires a valid super admin bearer token / API key.
 */
export async function createTestOrg(
  request: APIRequestContext,
  authKey: string,
  overrides: Partial<{
    slug: string;
    name: string;
    plan: string;
    seats: number;
    githubOrg: string;
  }> = {}
) {
  const slug = overrides.slug || uniqueSlug("org");
  const resp = await request.post("/super-admin/orgs", {
    headers: apiKeyHeader(authKey),
    data: {
      slug,
      name: overrides.name || `Test Org ${slug}`,
      plan: overrides.plan || "team",
      seats: overrides.seats || 10,
      githubOrg: overrides.githubOrg || "test-github-org",
    },
  });
  return { resp, slug };
}
