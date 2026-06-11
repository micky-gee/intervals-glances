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

DEVICE=fenix8pro47mm
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
