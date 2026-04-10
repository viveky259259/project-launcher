# Developer Onboarding Guide

This guide covers joining a Project Launcher workspace from scratch: installing the CLI, joining a workspace, and completing the onboarding checklist.

---

## Prerequisites

- **`plauncher` CLI** installed. If not, ask your org admin or see the [install guide](../install.sh).
- **git** available on your `PATH`.
- An **API key** from your org admin (format: `plk_...`).
- The **catalog server URL** for your deployment (e.g. `https://catalog.acme.internal`).
- Your **org slug** (e.g. `acme-corp`). The server may return it automatically; ask your admin if unsure.

---

## Joining a Workspace

Run `plauncher join` with your server URL and API key:

```bash
plauncher join https://catalog.acme.internal \
  --token plk_your_api_key_here \
  --org acme-corp
```

### Flags

| Flag | Short | Description |
|---|---|---|
| `--token` | `-t` | API key or JWT. Required unless a saved token exists or the server supports GitHub OAuth. |
| `--org` | `-o` | Org slug. The server returns it from `GET /health` in self-hosted single-org mode; provide it explicitly in multi-org deployments. |
| `--base-path` | `-b` | Local directory where repos are cloned. Defaults to `$HOME/src`. |

### What Happens During Join

`plauncher join` runs the full onboarding flow in sequence:

1. **Authentication** — resolves a token in this order: `--token` flag → saved token for this server → browser OAuth (if the server supports it). Once a token is resolved it is saved to `~/.project_launcher/auth.json` for future commands.

2. **Catalog fetch** — calls `GET /api/orgs/<slug>/catalog` and prints the catalog name, total repos, and how many are marked required.

3. **Clone required repos** — for each repo where `required: true`, runs `git clone <url> <base-path>/<name>`. Already-existing directories are skipped.

4. **Env setup** — for each required repo that has an `envTemplate` assigned, prompts you to enter key=value pairs for variables marked as `ask`. Variables with `default` values are written automatically. Type one variable per line, then press Enter on a blank line to finish. The result is written to `<base-path>/<repo-name>/.env`.

5. **Build verify** — runs `flutter pub get` (Flutter repos) or `cargo build` (Rust repos) in each required repo. Reports pass or fail.

6. **Test verify** — runs `flutter test` or `cargo test` in each required repo. Reports pass or fail.

When complete, all steps are reported to the server so your org admin can see your onboarding progress.

---

## The Onboarding Checklist

Each step has one of four statuses:

| Symbol | Status | Meaning |
|---|---|---|
| `○` | pending | Not started. |
| `⏳` | inProgress | Started but needs input. |
| `✓` | done | Completed successfully. |
| `✗` | failed | Completed with errors. |

**Step IDs:**

| Step ID | What it means |
|---|---|
| `clone_<repo-name>` | The repo was (or needs to be) cloned locally. One step per required repo. |
| `env_<repo-name>` | The `.env` file for the repo was (or needs to be) populated. One step per repo with an env template. |
| `build_verify` | `flutter pub get` / `cargo build` passed for all required repos. |
| `test_verify` | `flutter test` / `cargo test` passed for all required repos. |

---

## Checking Status

```bash
plauncher onboarding status
```

Prints the current checklist with progress percentage. Uses saved auth by default.

To check against a specific server:

```bash
plauncher onboarding status --server https://catalog.acme.internal
```

---

## Resuming a Paused Onboarding

If `plauncher join` was interrupted, or if a step failed, resume from the first incomplete step:

```bash
plauncher onboarding continue
```

With explicit options:

```bash
plauncher onboarding continue \
  --server https://catalog.acme.internal \
  --base-path ~/src
```

`continue` drives each remaining step in order:
- Clone steps: re-checks whether the directory exists. If the repo URL is unavailable in the status response, it directs you to re-run `plauncher join` instead.
- Env steps: prints the repo path and asks you to fill in `<base-path>/<repo>/.env` manually, then re-run `continue`.
- `build_verify` / `test_verify`: re-runs the appropriate build/test command.

---

## Setting Up "Ask" Variables

When `plauncher join` reaches the env setup step for a repo, it prints the template name and prompts:

```
  → Setup env for api-service (has env template: api-service-env)
  Enter environment variables (leave blank to skip):
  > DATABASE_URL=postgres://localhost:5432/mydb
  > STRIPE_SECRET=sk_test_...
  >
  ✓ Wrote .env
```

Alternatively, if you are using the Project Launcher Flutter app:
1. Open the app and find the repo in the catalog.
2. Click the env template chip to open the **Env Template Dialog**.
3. Fill in the `ask`-type variables and save. The app writes `.env` to the cloned repo path.

Variables with `type: default` are pre-populated automatically. Variables with `type: vault` display the vault path — fetch the value from your secrets manager and enter it at the prompt.

---

## Reconnecting or Switching Workspaces

Saved auth lives in `~/.project_launcher/auth.json`. To connect to a different workspace, run `plauncher join` with the new server URL:

```bash
plauncher join https://catalog.other-company.com \
  --token plk_their_key \
  --org other-company
```

This overwrites the saved auth. Subsequent `plauncher onboarding` commands use the new server automatically.

To go back to a previous workspace, run `plauncher join` again pointing at the original server.

---

## Troubleshooting

### Token expired or rejected (401)

Your JWT has expired or your API key was revoked.

```
Server returned 401 for GET .../catalog
```

Re-run `plauncher join` with a fresh API key from your org admin:

```bash
plauncher join https://catalog.acme.internal --token plk_new_key
```

### Catalog out of date

The CLI fetches the catalog fresh on every `plauncher join`. If you need to refresh without re-running the full onboarding, re-run:

```bash
plauncher join https://catalog.acme.internal
```

New required repos that were added to the catalog since your last join will be cloned.

### Clone failures

```
  [2/3] Cloning api-service... ✗
    stderr: fatal: repository 'https://github.com/acme-corp/api-service' not found
```

Common causes:
- You do not have read access to the repository on GitHub. Ask your GitHub org admin to add you.
- The URL in the catalog is wrong. Ask your org admin to correct it in the catalog.
- SSH auth required but HTTPS URL used (or vice versa). Ensure your git credentials are configured for HTTPS, or ask the admin to use an SSH URL.

After fixing access, re-run:

```bash
plauncher join https://catalog.acme.internal
```

Already-cloned repos are skipped.

### "Could not determine org slug"

```
  ! Could not determine org slug. Provide it with --org:
    plauncher join https://... --token <key> --org <slug>
```

The server did not return an org slug from `GET /health`. Provide `--org` explicitly:

```bash
plauncher join https://catalog.acme.internal --token plk_... --org acme-corp
```

### Build or test verify failed

Build and test failures do not block the join flow — the CLI records the failure and continues. Fix the underlying issue in the repo (missing dependencies, failing tests) and then re-run:

```bash
plauncher onboarding continue
```

### Not authenticated

```
Not authenticated. Run `plauncher join <url> --token <key>` first.
```

No saved auth exists for the server. Run `plauncher join` once with `--token` to save credentials.
