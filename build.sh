#!/bin/zsh
# Build the intervals.icu widget for the Fenix 8 Pro (incl. MicroLED).
# Usage: ./build.sh [--release]
set -e
setopt null_glob
cd "$(dirname "$0")"

# monkeyc needs a Java runtime (the /usr/bin/java stub doesn't count).
if [ -x /opt/homebrew/opt/openjdk/bin/java ]; then
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
    export JAVA_HOME=/opt/homebrew/opt/openjdk
fi

DEVICE=${DEVICE:-fenix8pro47mm}
OUT=bin/intervals-widget.prg
KEY=developer_key.der

# Locate the SDK: prefer the SDK-manager-installed one, fall back to Homebrew.
SDK=""
for d in "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"/connectiq-sdk-mac-*(N) \
         /opt/homebrew/Caskroom/connectiq/*/connectiq-sdk-mac-*(N); do
    SDK="$d"
done
if [ -z "$SDK" ]; then
    echo "No ConnectIQ SDK found. Install with: brew install --cask connectiq" >&2
    exit 1
fi
echo "Using SDK: $SDK"

# One-time developer signing key.
if [ ! -f "$KEY" ]; then
    echo "Generating developer signing key..."
    openssl genrsa -out developer_key.pem 4096 2>/dev/null
    openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out "$KEY" -nocrypt
fi

# Store upload packages (.iq for apps.garmin.com). The personal .apikey is
# deliberately NOT baked in - store users enter their own key in settings.
#
#   --export        beta channel (manifest's app ID)
#   --export-prod   production channel: a store listing needs its own app ID,
#                   distinct from the beta listing's, so the prod build swaps
#                   in PROD_ID. Keep PROD_ID stable across releases.
PROD_ID="45d6851e2d794d53afd7ab6656adab9d"
if [ "$1" = "--export" ] || [ "$1" = "--export-prod" ]; then
    mkdir -p bin
    OUT_IQ=bin/intervals-widget-beta.iq
    if [ "$1" = "--export-prod" ]; then
        OUT_IQ=bin/intervals-widget-prod.iq
        cp manifest.xml manifest.xml.orig
        restore_manifest() {
            if [ -f manifest.xml.orig ]; then
                mv manifest.xml.orig manifest.xml
            fi
        }
        trap restore_manifest EXIT
        sed -i '' "s/iq:application id=\"[0-9a-f]*\"/iq:application id=\"$PROD_ID\"/" manifest.xml
    fi
    "$SDK/bin/monkeyc" -e -f monkey.jungle -y "$KEY" -o "$OUT_IQ" -r -w
    echo ""
    echo "Built $OUT_IQ (no API key baked in)."
    echo "Upload at https://apps.garmin.com/developer/dashboard"
    exit 0
fi

RELEASE=""
if [ "$1" = "--release" ]; then
    RELEASE="-r"
fi

# Personal builds: if a .apikey file exists (gitignored), bake it in as the
# apiKey property default so the sideloaded app needs no configuration.
PROPS=resources/settings/properties.xml
restore_props() {
    if [ -f "$PROPS.orig" ]; then
        mv "$PROPS.orig" "$PROPS"
    fi
}
if [ -f .apikey ]; then
    cp "$PROPS" "$PROPS.orig"
    trap restore_props EXIT
    sed -i '' "s|<property id=\"apiKey\" type=\"string\">[^<]*</property>|<property id=\"apiKey\" type=\"string\">$(cat .apikey)</property>|" "$PROPS"
fi

mkdir -p bin
"$SDK/bin/monkeyc" -f monkey.jungle -d $DEVICE -o "$OUT" -y "$KEY" -w $RELEASE
echo ""
echo "Built $OUT"
echo "Sideload: copy it to the watch's /GARMIN/Apps folder (USB/MTP),"
echo "or run in the simulator:  $SDK/bin/connectiq && $SDK/bin/monkeydo $OUT $DEVICE"
