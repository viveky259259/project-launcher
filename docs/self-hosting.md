# Self-Hosting Guide

This guide covers running the Project Launcher Enterprise backend on your own infrastructure.

## Prerequisites

- Docker 24+ and Docker Compose v2
- A domain (or subdomain) with DNS pointed at your server
- A GitHub OAuth App (see [Registering a GitHub OAuth App](#registering-a-github-oauth-app))
- A valid license key (see [Obtaining a License Key](#obtaining-a-license-key))
- Ports 80 and 443 available, or a reverse proxy in front of the backend

---

## Quick Start

The repository ships a `docker-compose.yml` at the repo root. It starts the backend (`plauncher-backend`) and MongoDB together.

**1. Clone or copy the compose file to your server, then create a `.env` file:**

```bash
cp .env.example .env
$EDITOR .env
```

**2. Start the stack:**

```bash
docker compose up -d
```

The backend listens on `http://localhost:8743` by default. Put a reverse proxy in front of it (see [Reverse Proxy](#running-behind-a-reverse-proxy)).

**3. Verify the server is up:**

```bash
curl https://your-domain/health
# {"status":"ok","oauth":true}
```

---

## Environment Variables

Copy `.env.example` to `.env` and fill in every value before starting the stack.

### Required

| Variable | Description |
|---|---|
| `PLAUNCHER_JWT_SECRET` | Random secret used to sign JWTs. Use at least 32 random bytes. Never share this. |
| `GITHUB_CLIENT_ID` | Client ID from your GitHub OAuth App. |
| `GITHUB_CLIENT_SECRET` | Client secret from your GitHub OAuth App. |

### License

| Variable | Description |
|---|---|
| `PLAUNCHER_LICENSE_KEY` | Your license key (`lic_...`). Required for self-hosted mode. |
| `PLAUNCHER_LICENSE_URL` | Override the license validation endpoint. Defaults to `https://api.plauncher.dev/api/license/validate`. |

### Server Behaviour

| Variable | Description |
|---|---|
| `PLAUNCHER_MODE` | Set to `self-hosted`. Defaults to `cloud`. |
| `PORT` | Port the backend binds to inside the container. Defaults to `8743`. |

### Database

| Variable | Description |
|---|---|
| `MONGODB_URI` | MongoDB connection string. Defaults to `mongodb://mongo:27017` (the name of the Compose service). |
| `PLAUNCHER_DB_NAME` | Database name. Defaults to `plauncher`. |

### Bootstrap (first run only)

| Variable | Description |
|---|---|
| `PLAUNCHER_BOOTSTRAP_KEY` | A one-time API key used to seed the first super admin account. See [First-Run Bootstrap](#first-run-bootstrap). |

### OAuth Callback

| Variable | Description |
|---|---|
| `PLAUNCHER_CALLBACK_URI` | Full URL of the OAuth callback endpoint. Defaults to `http://localhost:8743/auth/callback`. **Must be set** to your public URL in production, e.g. `https://catalog.acme.internal/auth/callback`. |

---

## Obtaining a License Key

License keys are issued by the Project Launcher super admin portal at **[admin.plauncher.io](https://admin.plauncher.io)**. Log in with your GitHub account, navigate to **License Keys**, and generate a key for your organization. The key has the form `lic_...`.

Alternatively, if you have super admin API access, generate one via:

```bash
curl -X POST https://admin.plauncher.io/super-admin/license-keys \
  -H "Authorization: Bearer <super-admin-token>" \
  -H "Content-Type: application/json" \
  -d '{"orgSlug": "acme-corp", "seats": 50, "plan": "enterprise"}'
```

Set the returned key in your `.env`:

```
PLAUNCHER_LICENSE_KEY=lic_your_key_here
```

The server validates the key at startup against `PLAUNCHER_LICENSE_URL`. If the validation server is unreachable, a 7-day grace period applies before the warning becomes blocking.

---

## Registering a GitHub OAuth App

1. Go to **GitHub → Settings → Developer settings → OAuth Apps → New OAuth App**.
2. Fill in:
   - **Application name**: anything (e.g. "Acme Project Launcher")
   - **Homepage URL**: `https://your-domain`
   - **Authorization callback URL**: `https://your-domain/auth/callback`
3. Click **Register application**.
4. Copy the **Client ID** into `GITHUB_CLIENT_ID`.
5. Generate a **Client Secret** and copy it into `GITHUB_CLIENT_SECRET`.
6. Set `PLAUNCHER_CALLBACK_URI=https://your-domain/auth/callback` in `.env`.

The OAuth flow uses the scopes `read:org,user` to verify GitHub organization membership during login.

---

## First-Run Bootstrap

On a fresh install there are no super admins. The `PLAUNCHER_BOOTSTRAP_KEY` mechanism lets you seed the first one without going through GitHub OAuth.

1. Generate a strong random string (this becomes a one-time API key):

   ```bash
   openssl rand -hex 32
   # e.g. 4b3c2a1d...
   ```

2. Add it to `.env` before starting the server:

   ```
   PLAUNCHER_BOOTSTRAP_KEY=4b3c2a1d...
   ```

3. Start the stack. The server will create a `bootstrap-admin` super admin record and register the key. Check the logs:

   ```
   Bootstrap super admin key active — use it to create your admin account, then revoke it
   ```

4. Use the key to authenticate with the super admin API and create your real super admin account.

5. Once your real account is set up, **revoke the bootstrap key** via the super admin API and remove `PLAUNCHER_BOOTSTRAP_KEY` from `.env`. The bootstrap process is a no-op if any super admin already exists.

---

## Running Behind a Reverse Proxy

The recommended setup is nginx with Let's Encrypt SSL terminating in front of the backend.

**Example nginx configuration:**

```nginx
server {
    listen 80;
    server_name catalog.acme.internal;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name catalog.acme.internal;

    ssl_certificate     /etc/letsencrypt/live/catalog.acme.internal/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/catalog.acme.internal/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:8743;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        # Allow longer timeouts for catalog publish (git commit)
        proxy_read_timeout 60s;
    }
}
```

Obtain a certificate with Certbot:

```bash
certbot --nginx -d catalog.acme.internal
```

Make sure `PLAUNCHER_CALLBACK_URI` in `.env` matches the public HTTPS URL exactly:

```
PLAUNCHER_CALLBACK_URI=https://catalog.acme.internal/auth/callback
```

---

## Updating to a New Version

```bash
# Pull latest images
docker compose pull

# Restart with zero-downtime rolling update
docker compose up -d

# Confirm the new version is running
docker compose ps
curl https://your-domain/health
```

MongoDB data is persisted in a named volume (`mongo_data`) and is not affected by container replacement.

---

## Troubleshooting

### MongoDB connection refused

```
Error: Failed to connect to mongodb://mongo:27017
```

The backend container starts before MongoDB is ready. Wait a few seconds and check:

```bash
docker compose logs mongo
docker compose restart backend
```

If `MONGODB_URI` points to an external host, verify network reachability and that the URI includes credentials if authentication is enabled.

### Port 8743 already in use

Change the host-side port in `docker-compose.yml`:

```yaml
ports:
  - "9000:8743"   # map host:container
```

Update your reverse proxy config to match.

### OAuth callback mismatch (GitHub 400)

GitHub rejects the callback if the `redirect_uri` sent during authorization does not exactly match the one registered in the OAuth App. Check:

1. `PLAUNCHER_CALLBACK_URI` in `.env` equals the **Authorization callback URL** in your GitHub OAuth App settings.
2. The URL is accessible from the internet (not a private IP).

### License validation warnings at startup

```
License validation server unreachable — Entering 7-day grace period
```

The backend could not reach `PLAUNCHER_LICENSE_URL`. Verify outbound HTTPS connectivity from the container, or set `PLAUNCHER_LICENSE_URL` to an internal mirror if you are running fully air-gapped.
