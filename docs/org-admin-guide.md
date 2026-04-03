# Org Admin Guide

This guide covers everything an OrgAdmin can do: managing members, maintaining the catalog, configuring env templates, and issuing API keys.

---

## What an Org Admin Can Do

| Capability | OrgAdmin | Developer |
|---|---|---|
| View catalog | Yes | Yes |
| Edit catalog | Yes | No |
| Publish catalog | Yes | No |
| Invite / remove members | Yes | No |
| Change member roles | Yes | No |
| Generate API keys for members | Yes | No |
| Revoke API keys | Yes | No |
| Create / edit env templates | Yes | No |
| Run onboarding | Yes | Yes |

---

## Accessing the Admin Portal

The admin API is served at:

```
https://<your-deployment>/api/orgs/<slug>/admin/...
```

Where `<slug>` is your organization's URL slug (e.g. `acme-corp`).

**Authentication options:**

- **GitHub OAuth** — navigate to `https://<your-deployment>/auth/<slug>/github` in a browser. After authorizing, you receive a JWT. Pass it as `Authorization: Bearer <token>` on subsequent requests.
- **API key** — use an API key issued by a super admin or by the invite flow. Pass it as `Authorization: Bearer <api-key>`.

Both token types are accepted on all admin endpoints. JWTs expire; API keys do not unless revoked.

---

## Managing Members

### Listing Members

```http
GET /api/orgs/:slug/admin/members
Authorization: Bearer <token>
```

Returns each member's GitHub login, role, join date, last-seen date, number of repos synced, total catalog repos, and whether they are drifted (have fewer synced repos than the current catalog).

### Inviting a Member

```http
POST /api/orgs/:slug/admin/members/invite
Authorization: Bearer <token>
Content-Type: application/json

{
  "githubLogin": "jdoe",
  "role": "developer"
}
```

The invited user must be a member of the GitHub organization configured for the org (`githubOrg`). If GitHub OAuth is enabled, the backend verifies membership at login time.

On success the response includes the new member's initial API key:

```json
{
  "member": "jdoe",
  "apiKey": "plk_..."
}
```

Send this key to the new developer so they can run `plauncher join`.

Valid roles: `orgAdmin`, `developer`. `superAdmin` cannot be assigned via this endpoint.

### Changing a Member's Role

```http
PATCH /api/orgs/:slug/admin/members/:login
Authorization: Bearer <token>
Content-Type: application/json

{
  "role": "orgAdmin"
}
```

### Removing a Member

```http
DELETE /api/orgs/:slug/admin/members/:login
Authorization: Bearer <token>
```

Removing a member does not automatically revoke their API keys. Revoke keys separately (see [API Key Management](#api-key-management)).

---

## Managing the Catalog

The catalog is the source of truth for which repos belong to the org, which are required for onboarding, and which env template each repo uses.

### Fetching the Current Catalog

```http
GET /api/orgs/:slug/admin/catalog
Authorization: Bearer <token>
```

### Updating the Catalog

```http
PUT /api/orgs/:slug/admin/catalog
Authorization: Bearer <token>
Content-Type: application/json

{
  "version": "1.2.0",
  "repos": [
    {
      "name": "api-service",
      "url": "https://github.com/acme-corp/api-service",
      "required": true,
      "tags": ["backend", "core"],
      "envTemplate": "api-service-env"
    },
    {
      "name": "design-system",
      "url": "https://github.com/acme-corp/design-system",
      "required": false,
      "tags": ["frontend"],
      "envTemplate": null
    }
  ],
  "envTemplates": []
}
```

`PUT /catalog` saves the catalog to the database but does not write a git commit.

### Publishing the Catalog

```http
POST /api/orgs/:slug/admin/catalog/publish
Authorization: Bearer <token>
Content-Type: application/json

{ ...same body as PUT /catalog... }
```

`POST /catalog/publish` saves to the database **and** attempts to write `catalogs/<slug>/catalog.yaml` and commit it to the local git repository inside the backend container. The response indicates whether the commit succeeded:

```json
{
  "committed": true,
  "sha": "abc1234..."
}
```

If git is not available or the working tree is not a repository, `committed` is `false` and `reason` explains why. The database update still succeeds regardless.

### Repo Fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Repository name (used as the clone directory name). |
| `url` | string | Full HTTPS clone URL. |
| `required` | boolean | If `true`, `plauncher join` clones this repo automatically. |
| `tags` | string[] | Arbitrary labels for filtering. |
| `envTemplate` | string \| null | Name of an env template to apply during onboarding. |

---

## Env Templates

Env templates describe the environment variables a repo needs. Each variable has one of three types:

| Type | Meaning |
|---|---|
| `default` | A known safe default value. Written to `.env` automatically. |
| `ask` | Developer must supply the value. CLI prompts for it; Flutter app shows the env template dialog. |
| `vault` | Value should be fetched from a secrets manager at the given `path`. |

### Listing Templates

```http
GET /api/orgs/:slug/admin/templates
Authorization: Bearer <token>
```

### Creating a Template

```http
POST /api/orgs/:slug/admin/templates
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "api-service-env",
  "vars": {
    "DATABASE_URL": { "type": "ask" },
    "LOG_LEVEL": { "type": "default", "value": "info" },
    "STRIPE_SECRET": { "type": "vault", "path": "secret/acme/stripe" }
  }
}
```

### Updating a Template

```http
PUT /api/orgs/:slug/admin/templates/:name
Authorization: Bearer <token>
Content-Type: application/json

{
  "vars": {
    "DATABASE_URL": { "type": "ask" },
    "LOG_LEVEL": { "type": "default", "value": "debug" }
  }
}
```

### Deleting a Template

```http
DELETE /api/orgs/:slug/admin/templates/:name
Authorization: Bearer <token>
```

### Assigning a Template to a Repo

Set the `envTemplate` field on the repo entry to the template name when calling `PUT /catalog` or `POST /catalog/publish`. The CLI and Flutter app look up the template by name when running onboarding.

---

## API Key Management

### Generating a Key for a Member

A key is automatically generated when a member is first invited. You can generate additional keys at any time:

```http
POST /api/orgs/:slug/admin/members/:login/keys
Authorization: Bearer <token>
```

Response:

```json
{
  "apiKey": "plk_..."
}
```

The full key is only shown once. Store it or send it directly to the developer.

### Listing Keys for a Member

```http
GET /api/orgs/:slug/admin/members/:login/keys
Authorization: Bearer <token>
```

Returns masked keys (prefix only), role, creation date, last-used date, and revocation status. The full key is never returned after initial creation.

### Revoking a Key

```http
DELETE /api/orgs/:slug/admin/members/:login/keys/:key_prefix
Authorization: Bearer <token>
```

Revoked keys are immediately rejected by the auth middleware.

---

## Role Reference

**OrgAdmin**
- Full access to all `/api/orgs/:slug/admin/...` endpoints.
- Can invite, remove, and change the role of any non-super-admin member.
- Can publish the catalog and manage env templates.

**Developer**
- Read access to the public catalog and onboarding endpoints.
- Cannot access any `/admin/` route.
- Runs `plauncher join` and `plauncher onboarding` commands.
