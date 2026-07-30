// Cloudflare Worker: intervals.icu OAuth token exchange for Intervals Glances.
//
// The watch cannot hold the client secret (anything in a .prg is extractable
// and intervals.icu has no PKCE), so this Worker performs the code -> token
// exchange. It holds the secret as a Worker secret, processes each request in
// memory, and stores nothing.
//
// Deploy: see worker/README.md.

// Verified live: this is the only working path. Note intervals.icu answers
// bad client credentials with HTTP 404 and a descriptive body ("Client and/or
// secret not found"), so never treat a 404 here as a wrong URL.
const TOKEN_URL = "https://intervals.icu/api/oauth/token";

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("POST only", { status: 405 });
    }

    // Accept both form-encoded (Connect IQ makeWebRequest default) and JSON.
    let code = null;
    const ctype = request.headers.get("content-type") || "";
    try {
      if (ctype.includes("application/json")) {
        code = (await request.json()).code;
      } else {
        code = (await request.formData()).get("code");
      }
    } catch (e) {
      // fall through to the missing-code response
    }
    if (!code) {
      return Response.json({ error: "missing code" }, { status: 400 });
    }

    const body = new URLSearchParams({
      client_id: env.INTERVALS_CLIENT_ID,
      client_secret: env.INTERVALS_CLIENT_SECRET,
      code: code,
      redirect_uri: env.REDIRECT_URI,
      grant_type: "authorization_code",
    });

    const upstream = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });

    // Pass intervals.icu's response through (success JSON contains
    // access_token; failures keep their status so the watch can report them).
    return new Response(await upstream.text(), {
      status: upstream.status,
      headers: { "content-type": "application/json" },
    });
  },
};
