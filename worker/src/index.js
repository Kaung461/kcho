// K帳 AI proxy — holds the real Groq API key as a Worker secret so it never
// ships inside the public Flutter web build. See ../README.md for setup.

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

// Models the app actually calls today. Reject anything else so a caller
// can't use this proxy's key to run up usage on a different, more
// expensive model.
const ALLOWED_MODELS = ["openai/gpt-oss-20b"];

// Hard ceiling on response length, regardless of what the caller asks for.
const MAX_TOKENS_CAP = 4096;

// Reject oversized request bodies outright.
const MAX_BODY_BYTES = 32 * 1024;

// Origins allowed to call this proxy. The Flutter web dev server picks a
// random localhost port, so that one is matched by pattern instead of an
// exact entry.
const ALLOWED_ORIGINS = ["https://kaung461.github.io"];

function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (ALLOWED_ORIGINS.includes(origin)) return true;
  return /^http:\/\/localhost(:\d+)?$/.test(origin);
}

function corsHeaders(origin) {
  const headers = { Vary: "Origin" };
  if (isAllowedOrigin(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
    headers["Access-Control-Allow-Methods"] = "POST, OPTIONS";
    headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization";
  }
  return headers;
}

function jsonResponse(data, status, origin) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
  });
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin");

    if (request.method === "OPTIONS") {
      if (!isAllowedOrigin(origin)) return new Response(null, { status: 403 });
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    const url = new URL(request.url);
    if (url.pathname !== "/chat" || request.method !== "POST") {
      return jsonResponse({ error: "not found" }, 404, origin);
    }

    if (!isAllowedOrigin(origin)) {
      return jsonResponse({ error: "origin not allowed" }, 403, origin);
    }

    const contentLength = Number(request.headers.get("Content-Length") || "0");
    if (contentLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "request too large" }, 413, origin);
    }

    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "request too large" }, 413, origin);
    }

    let body;
    try {
      body = JSON.parse(raw);
    } catch (_) {
      return jsonResponse({ error: "invalid JSON body" }, 400, origin);
    }

    if (!ALLOWED_MODELS.includes(body.model)) {
      return jsonResponse({ error: "model not allowed" }, 400, origin);
    }
    if (body.stream === true) {
      return jsonResponse({ error: "streaming not supported" }, 400, origin);
    }
    if (!Array.isArray(body.messages) || body.messages.length === 0) {
      return jsonResponse({ error: "messages required" }, 400, origin);
    }

    // Note: the app sends an Authorization: Bearer <Firebase ID token>
    // header to identify the caller for possible future use (e.g.
    // per-user limits). This Worker does not verify that token yet —
    // see the README's "known gaps" section.
    const forwardBody = {
      ...body,
      max_tokens: Math.min(Number(body.max_tokens) || MAX_TOKENS_CAP, MAX_TOKENS_CAP),
    };

    let upstream;
    try {
      upstream = await fetch(GROQ_ENDPOINT, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${env.GROQ_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(forwardBody),
      });
    } catch (_) {
      return jsonResponse({ error: "upstream unreachable" }, 502, origin);
    }

    let upstreamJson;
    try {
      upstreamJson = await upstream.json();
    } catch (_) {
      return jsonResponse({ error: "upstream returned invalid JSON" }, 502, origin);
    }

    if (!upstream.ok) {
      // Never echo the upstream body (it could contain anything, including
      // details we don't want to pass through) — just the status.
      return jsonResponse({ error: "upstream error" }, upstream.status, origin);
    }

    return jsonResponse(upstreamJson, 200, origin);
  },
};
