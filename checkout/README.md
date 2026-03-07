# Checkout Pages for Project Launcher

Static pages that handle Paddle checkout and subscription management.

## Files

- `index.html` — Checkout page (opens Paddle overlay for purchase)
- `portal.html` — Billing portal (manage subscription)

## Setup

### 1. Get your Paddle Client Token

Go to **Paddle Dashboard → Developer Tools → Authentication** and copy the **Client-side token** (starts with `test_` for sandbox or `live_` for production).

### 2. Update tokens in both files

Replace `test_REPLACE_WITH_CLIENT_TOKEN` with your actual client token in:
- `index.html` (line with `PADDLE_CLIENT_TOKEN`)
- `portal.html` (line with `PADDLE_CLIENT_TOKEN`)

### 3. Update plan display info

In `index.html`, update the `planNames` object with your actual price IDs and display info.

### 4. Deploy

Deploy this folder as a static site to `checkout.projectlauncher.dev`.

Options:
- **Cloudflare Pages**: `npx wrangler pages deploy .`
- **Vercel**: `vercel --prod`
- **Netlify**: drag & drop the folder
- **GitHub Pages**: push to a repo and enable Pages

### 5. For production

In both HTML files, change:
- `IS_SANDBOX = false`
- `PADDLE_API_BASE` to `https://api.paddle.com` (in portal.html)
- Client token from `test_` to `live_` prefix

## How it works

1. User clicks "Subscribe" in the app
2. App opens `checkout.projectlauncher.dev?price_id=pri_xxx&custom_data={"app_user_id":"plr_xxx"}`
3. Page loads Paddle.js and auto-opens the checkout overlay
4. User completes payment
5. App polls Paddle API for subscription activation
