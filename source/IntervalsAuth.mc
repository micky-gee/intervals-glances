import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// OAuth sign-in: opens the intervals.icu consent page via Garmin Connect
// Mobile, receives the one-time authorization code, exchanges it for a
// long-lived access token via the Cloudflare Worker that holds the client
// secret (see worker/README.md), and stores the token. Foreground only.
//
// The callbacks live on a persistent singleton (method() needs an instance,
// and the registration must outlive the START press: Garmin caches a result
// produced while the widget was closed and delivers it to whatever callback
// is registered next).
module IntervalsAuth {

    const CLIENT_ID = "649";

    // Garmin Connect Mobile only captures the OAuth result when the consent
    // page redirects to http://localhost - it watches for that navigation and
    // never actually loads it. Any other redirect (even one registered with
    // the provider) is silently ignored on real hardware, so this value is
    // mandatory, not a preference. intervals.icu always allows localhost.
    const REDIRECT_URL = "http://localhost";

    const EXCHANGE_URL = "https://intervals-oauth.micky-gee.workers.dev/";

    // A login can take minutes, or be abandoned on the phone. Cap the
    // "connecting" state so the user can always retry.
    const ATTEMPT_TIMEOUT = 180;

    var _flow as Flow? = null;

    function flow() as Flow {
        if (_flow == null) {
            _flow = new Flow();
        }
        return _flow;
    }

    // Called once at app start; also flushes any cached OAuth result.
    function init() as Void {
        flow().register();
    }

    function busy() as Boolean {
        return flow().isBusy();
    }

    function connect() as Void {
        flow().connect();
    }

    class Flow {
        hidden var _since as Number = 0;

        function initialize() {
        }

        function register() as Void {
            Communications.registerForOAuthMessages(method(:onMessage));
        }

        function isBusy() as Boolean {
            return _since != 0 && Time.now().value() - _since < ATTEMPT_TIMEOUT;
        }

        function connect() as Void {
            if (isBusy()) {
                return;
            }
            _since = Time.now().value();
            register();
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
            WatchUi.requestUpdate();
        }

        function onMessage(msg as Communications.OAuthMessage) as Void {
            var code = null;
            var d = msg.data;
            if (d instanceof Lang.Dictionary) {
                code = d["code"];
            }
            if (!(code instanceof Lang.String) || code.length() == 0) {
                System.println("oauth: no code in message");
                _since = 0;
                Storage.setValue("err", "Connect cancelled");
                WatchUi.requestUpdate();
                return;
            }
            // The code expires in 2 minutes; exchange it immediately. The
            // dictionary is sent form-encoded, which the Worker accepts.
            Communications.makeWebRequest(EXCHANGE_URL, { "code" => code }, {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            }, method(:onToken));
        }

        function onToken(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
            _since = 0;
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
