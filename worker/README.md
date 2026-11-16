# K帳 AI proxy (Cloudflare Worker)

Holds the real Groq API key as a secret, so it never ships inside the
Flutter web build. The app calls this Worker's `/chat` endpoint; the Worker
attaches the key and forwards to Groq, then returns Groq's response as-is.

Background: the previous setup baked the Groq key into the app via
`--dart-define`, which ends up as plaintext in the compiled `main.dart.js`.
Since that file is served from a public GitHub Pages site, the key was
publicly readable — and got auto-revoked. This Worker is the fix: the key
now lives only here.

## One-time setup (run these yourself)

```sh
npm i -g wrangler
wrangler login
```

```sh
cd worker
wrangler secret put GROQ_API_KEY
# paste the NEW Groq key when prompted (create it in the Groq console first;
# delete the old/leaked one there too)
```

```sh
wrangler deploy
```

The deploy output prints the Worker's URL, shaped like:

```
https://kcho-ai-proxy.<your-subdomain>.workers.dev
```

That whole URL (no trailing slash) is the `AI_PROXY_URL` value — set it as
a GitHub repository **Variable** (Settings → Secrets and variables →
Actions → Variables tab, not Secrets — it's not a secret):

```
Name:  AI_PROXY_URL
Value: https://kcho-ai-proxy.<your-subdomain>.workers.dev
```

Then delete the old `GROQ_API_KEY` repository **secret** — the key no
longer belongs in this repo or in the Flutter build at all.

## Local testing

```sh
cd worker
wrangler dev
```

This runs the Worker locally (prints a `http://localhost:8787` URL) using
the same secret you set with `wrangler secret put`. Run the Flutter app
against it with:

```sh
flutter run -d chrome --dart-define=AI_PROXY_URL=http://localhost:8787
```

`http://localhost:*` is in the Worker's CORS allow-list already, so this
works without touching `ALLOWED_ORIGINS` in `src/index.js`.

To test the three AI features end to end: open the app, (1) add a new
word and tap "AIで自動補完", (2) generate a reading passage from Home, (3)
write a line in 作文 and tap "AIに添削してもらう". Each should return
normally; if the Worker is misconfigured you'll see the app's own error
alert (e.g. "サーバーがエラーを返しました (…)") rather than a raw crash.

## What this Worker guards against

- Only `POST /chat` is served; everything else is 404/405.
- Only requests from `https://kaung461.github.io` or `http://localhost:*`
  are allowed (CORS + an explicit origin check, not just CORS headers).
- Only the model(s) the app actually uses (`openai/gpt-oss-20b`) are
  forwarded; anything else is rejected.
- `max_tokens` is capped at 4096 regardless of what's requested.
- Request bodies over 32 KB are rejected.
- `stream: true` is rejected (the app doesn't use streaming).
- Upstream (Groq) error bodies are never echoed back — only the status
  code, inside a small `{error: "..."}` JSON object.

## Known gap: no rate limiting yet

This Worker does **not** rate-limit callers per IP or per user. Cloudflare's
native Rate Limiting Rules are a dashboard/WAF feature not readily
scriptable from a Workers Free plan, and adding a Workers KV-based manual
limiter means extra setup (a KV namespace + binding) for a school project
where Groq's own free-tier cap (≈1,000 requests/day on this model) already
puts a ceiling on worst-case cost. Documenting this rather than building it
now; add a KV-backed per-IP limiter here if this ever gets real traffic.

The app also sends `Authorization: Bearer <Firebase ID token>` on every
request, but this Worker does not verify that token yet (verifying a
Firebase ID token from a Worker means fetching and checking against
Google's JWKS, which is more than a few lines to do correctly) — it's
there so a future version of this Worker can check it cheaply without any
client-side change.
