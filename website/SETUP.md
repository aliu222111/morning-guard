# MorningGuard Website — Setup Guide

## Files

| File | Purpose | App Store field |
|------|---------|----------------|
| `index.html` | Landing page + App Store download buttons | Marketing URL |
| `privacy.html` | Full privacy policy | Privacy Policy URL |
| `support.html` | FAQ + contact | Support URL |
| `styles.css` | Shared styles | — |
| `favicon.svg`, `apple-touch-icon.png` | Browser / home-screen icons | — |
| `og-image.png` | Social share preview (1200×630) | — |
| `screenshots/` | Real app screenshots used on the page | — |
| `og-card.html` | Source used to regenerate `og-image.png` (not deployed) | — |

---

## Step 1 — Drop in your real App Store ID

Every "Download" button currently points to the placeholder `[YOUR-APP-ID]`. Until you replace it, the buttons go nowhere.

1. In **App Store Connect → your app → App Information**, copy the **Apple ID** (a 10-digit number).
2. Find and replace **`[YOUR-APP-ID]`** with that number across the whole `website/` folder. It appears in:
   - `index.html` (nav button, hero button, bottom button)
   - `privacy.html` (nav button)
   - `support.html` (nav button)
3. The finished link looks like `https://apps.apple.com/app/id1234567890`.

Also update the app itself: in `MorningGuard/MorningGuard/SettingsView.swift`, replace `appStoreID = "0000000000"` with the same number so the in-app "Rate" button works.

---

## Step 2 — Deploy the website (Cloudflare Pages)

Cloudflare Pages is free, fast, and includes a global CDN and DDoS protection automatically.

1. Go to **https://pages.cloudflare.com** and sign in (or create a free Cloudflare account).
2. Click **Create a project → Upload assets**.
3. Give the project a name, e.g. `morningguard`.
4. Drag the entire `website/` folder into the upload box, then click **Deploy site**.
5. Cloudflare gives you a URL like `https://morningguard.pages.dev` within seconds.
6. **Custom domain** (recommended):
   - In the project dashboard go to **Custom domains → Set up a custom domain**.
   - Enter your domain (e.g. `morningguard.com`) and follow the DNS instructions. SSL is provisioned free.
7. For future updates: open the project, click **Upload assets** again, and re-upload the folder.

---

## Step 3 — Point the social image at your live domain

Open Graph scrapers (iMessage, Slack, X/Twitter, Facebook) need an **absolute** image URL.

In `index.html`, change:

```html
<meta property="og:image" content="og-image.png" />
<meta name="twitter:image" content="og-image.png" />
```

to your live URL, e.g. `https://morningguard.com/og-image.png`.

To regenerate the image after a copy change, edit `og-card.html`, open it in a browser at a 1200×630 viewport, and export a screenshot as `og-image.png`.

---

## Step 4 — Fill in the App Store Connect URLs

In **App Store Connect → your app → App Information**:

| Field | URL |
|-------|-----|
| **Marketing URL** | `https://yourdomain.com` (index.html) |
| **Support URL** | `https://yourdomain.com/support.html` |
| **Privacy Policy URL** | `https://yourdomain.com/privacy.html` |

---

## Step 5 — Confirm the contact inbox

All contact links use `hello@morningguard.com`. Make sure that inbox actually receives mail before you submit the Support URL — App Review may email it. To use a different address, find and replace `hello@morningguard.com` across the three HTML files (and `SettingsView.swift`).
