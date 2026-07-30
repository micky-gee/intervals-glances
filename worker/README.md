# intervals.icu OAuth token-exchange Worker

The watch app can't hold the OAuth client secret (no PKCE at intervals.icu, and
anything in a `.prg` is extractable), so this ~50-line Cloudflare Worker does
the one-time code → token exchange. It stores nothing; the secret lives only in
Cloudflare's secret store.

## 1. Register the app with intervals.icu

Email **david@intervals.icu** (see the [OAuth announcement](https://forum.intervals.icu/t/intervals-icu-oauth-support/2759)):

> Subject: OAuth app registration — Intervals Glances
>
> Hi David — please register an OAuth app:
>
> - **Name:** Intervals Glances
> - **Description:** Garmin Connect IQ watch widget showing fitness / fatigue /
>   form and wellness data from intervals.icu (glance + charts, read-only).
> - **Website:** https://micky-gee.github.io/intervals-glances/
> - **Logo:** https://micky-gee.github.io/intervals-glances/logo.png
> - **Privacy policy:** https://micky-gee.github.io/intervals-glances/privacy.html
> - **Redirect URI:** https://micky-gee.github.io/intervals-glances/oauth-done.html
> - **Scopes used:** WELLNESS:READ
> - **My athlete ID:** i######  (fill in)
>
> Thanks!

You'll receive a `client_id` and `client_secret`.

## 2. Deploy the Worker (free tier)

```sh
npm install -g wrangler
cd worker
wrangler login                                  # one-time browser auth
# put the public values in wrangler.toml:
#   INTERVALS_CLIENT_ID = "<client_id>"
wrangler secret put INTERVALS_CLIENT_SECRET     # paste the secret when prompted
wrangler deploy                                 # prints the workers.dev URL
```

## 3. Point the app at it

In `source/IntervalsAuth.mc` set:
- `CLIENT_ID` = the client_id
- `EXCHANGE_URL` = `https://intervals-oauth.<your-account>.workers.dev/`

## 4. Smoke test

```sh
curl -s -X POST https://intervals-oauth.<account>.workers.dev/ \
     -H 'content-type: application/json' -d '{"code":"bogus"}'
# expect an intervals.icu 4xx error passed through, e.g. invalid_grant
curl -s -X GET https://intervals-oauth.<account>.workers.dev/
# expect: POST only (405)
```
