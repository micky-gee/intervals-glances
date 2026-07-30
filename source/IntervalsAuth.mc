import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.WatchUi;

// OAuth sign-in: opens the intervals.icu consent page via Garmin Connect
// Mobile, receives the one-time authorization code, exchanges it for a
// long-lived access token via the Cloudflare Worker that holds the client
// secret (see worker/README.md), and stores the token. Foreground only.
module IntervalsAuth {

    // Registered with intervals.icu; the matching client secret lives only in
    // the Worker (see worker/README.md), never in the app.
    const CLIENT_ID = "649";
    const REDIRECT_URL = "https://micky-gee.github.io/intervals-glances/oauth-done.html";
    const EXCHANGE_URL = "https://intervals-oauth.micky-gee.workers.dev/";

    var _flow as Flow? = null;

    function busy() as Boolean {
        return _flow != null && _flow.busy;
    }

    function connect() as Void {
        if (busy()) {
            return;
        }
        _flow = new Flow();
        _flow.start();
    }

    class Flow {
        var busy as Boolean = false;

        function initialize() {
        }

        function start() as Void {
            busy = true;
            Communications.registerForOAuthMessages(method(:onMessage));
            Communications.makeOAuthRequest(
                "https://intervals.icu/oauth/authorize",
                {
                    "client_id" => CLIENT_ID,
                    "redirect_uri" => REDIRECT_URL,
                    "response_type" => "code",
                    "scope" => "WELLNESS:READ"
                },
                REDIRECT_URL,
                Communications.OAUTH_RESULT_TYPE_URL,
                { "code" => "code", "error" => "error" });
        }

        function onMessage(msg as Communications.OAuthMessage) as Void {
            var code = null;
            var d = msg.data;
            if (d instanceof Lang.Dictionary) {
                code = d["code"];
            }
            if (!(code instanceof Lang.String) || code.length() == 0) {
                busy = false;
                Storage.setValue("err", "Connect cancelled");
                WatchUi.requestUpdate();
                return;
            }
            // The code expires in 2 minutes; exchange immediately. The
            // dictionary is sent form-encoded, which the Worker accepts.
            Communications.makeWebRequest(EXCHANGE_URL, { "code" => code }, {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            }, method(:onToken));
        }

        function onToken(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
            busy = false;
            var resp = data as Lang.Object?;
            var token = null;
            if (code == 200 && resp instanceof Lang.Dictionary) {
                token = resp["access_token"];
            }
            if (token instanceof Lang.String && token.length() > 0) {
                Storage.setValue("oauth", token);
                Storage.deleteValue("err");
                System.println("oauth: connected");
                IntervalsRefresh.startNow();
            } else {
                // Only BLE-level failures (negative codes) get the specific
                // text; intervals.icu answers bad client credentials with a
                // 404, so HTTP statuses must not be mapped as API errors here.
                System.println("oauth: exchange failed " + code);
                Storage.setValue("err",
                    code < 0 ? IntervalsApi.errorText(code) : "Connect failed");
            }
            WatchUi.requestUpdate();
        }
    }
}
