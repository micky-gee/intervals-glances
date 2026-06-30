#!/usr/bin/env bash
# Build the intervals.icu widget.
# Works on macOS and Windows (Git Bash).
# Usage: ./build.sh [--release] [--export] [--export-prod] [--all]
set -e
shopt -s nullglob
cd "$(dirname "$0")"

# Detect platform.
case "$(uname -s)" in
    Darwin*)        PLATFORM=mac ;;
    MSYS*|MINGW*)   PLATFORM=win ;;
    *)              PLATFORM=linux ;;
esac

# Java — macOS Homebrew and common Windows JDK locations.
if [ "$PLATFORM" = "mac" ] && [ -x /opt/homebrew/opt/openjdk/bin/java ]; then
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
    export JAVA_HOME=/opt/homebrew/opt/openjdk
elif [ "$PLATFORM" = "win" ]; then
    for d in "/c/Program Files/Microsoft"/jdk-*/; do
        if [ -x "${d}bin/java" ]; then
            export JAVA_HOME="$d"
            export PATH="${d}bin:$PATH"
            break
        fi
    done
fi

DEVICE=${DEVICE:-fenix8pro47mm}
OUT=bin/intervals-widget.prg
KEY=developer_key.der

# Locate the SDK.
SDK=""
if [ "$PLATFORM" = "mac" ]; then
    for d in "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"/connectiq-sdk-mac-* \
             /opt/homebrew/Caskroom/connectiq/*/connectiq-sdk-mac-*; do
        SDK="$d"
    done
    MONKEYC="$SDK/bin/monkeyc"
else
    APPDATA_UNIX="$(cygpath -u "$APPDATA" 2>/dev/null || echo "$APPDATA")"
    for d in "$APPDATA_UNIX/Garmin/ConnectIQ/Sdks"/connectiq-sdk-win-*; do
        SDK="$d"
    done
    MONKEYC="$SDK/bin/monkeyc.bat"
fi

if [ -z "$SDK" ]; then
    echo "No ConnectIQ SDK found." >&2
    [ "$PLATFORM" = "mac" ] \
        && echo "Install with: brew install --cask connectiq" >&2 \
        || echo "Install from: https://developer.garmin.com/connect-iq/sdk/" >&2
    exit 1
fi
echo "Using SDK: $SDK"

# One-time developer signing key.
if [ ! -f "$KEY" ]; then
    echo "Generating developer signing key..."
    openssl genrsa -out developer_key.pem 4096 2>/dev/null
    openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out "$KEY" -nocrypt
fi

PROD_ID="45d6851e2d794d53afd7ab6656adab9d"

PROPS=resources/settings/properties.xml
restore_props() {
    if [ -f "$PROPS.orig" ]; then
        mv "$PROPS.orig" "$PROPS"
    fi
}
inject_key() {
    cp "$PROPS" "$PROPS.orig"
    trap restore_props EXIT
    # Use a temp file to avoid sed -i portability differences (BSD vs GNU).
    sed "s|<property id=\"apiKey\" type=\"string\">[^<]*</property>|<property id=\"apiKey\" type=\"string\">$1</property>|" \
        "$PROPS.orig" > "$PROPS"
}

# Store upload packages (.iq for apps.garmin.com).
if [ "$1" = "--export" ] || [ "$1" = "--export-prod" ]; then
    mkdir -p bin
    OUT_IQ=bin/intervals-widget-beta.iq
    if [ "$1" = "--export-prod" ]; then
        OUT_IQ=bin/intervals-widget-prod.iq
        cp manifest.xml manifest.xml.orig
        restore_manifest() {
            [ -f manifest.xml.orig ] && mv manifest.xml.orig manifest.xml
        }
        trap restore_manifest EXIT
        sed "s/iq:application id=\"[0-9a-f]*\"/iq:application id=\"$PROD_ID\"/" \
            manifest.xml.orig > manifest.xml
    fi
    "$MONKEYC" -e -f monkey.jungle -y "$KEY" -o "$OUT_IQ" -r -w
    echo ""
    echo "Built $OUT_IQ (no API key baked in)."
    echo "Upload at https://apps.garmin.com/developer/dashboard"
    exit 0
fi

RELEASE=""
[ "$1" = "--release" ] && RELEASE="-r"

# Sideload distribution: one .prg per device.
if [ "$1" = "--all" ]; then
    if [ -n "$APIKEY" ]; then
        echo "Baking provided APIKEY into all builds (do NOT publish these)."
        inject_key "$APIKEY"
    else
        echo "Building keyless .prgs (testers need a keyed build or the store version to sync)."
    fi
    mkdir -p dist
    rm -f dist/*.prg
    for d in $(grep -o 'product id="[a-z0-9]*"' manifest.xml | sed 's/.*id="//;s/"$//'); do
        out=$("$MONKEYC" -f monkey.jungle -d "$d" -o "dist/intervals-widget-$d.prg" -y "$KEY" -r 2>&1) \
            || { echo "FAIL $d"; echo "$out" | grep -m2 ERROR; exit 1; }
        echo "  $d"
    done
    echo "Built $(ls dist/*.prg | wc -l | tr -d ' ') device builds in dist/"
    exit 0
fi

# Default: debug build for DEVICE.
KEYVAL="${APIKEY:-}"
[ -z "$KEYVAL" ] && [ -f .apikey ] && KEYVAL=$(cat .apikey)
[ -n "$KEYVAL" ] && inject_key "$KEYVAL"

mkdir -p bin
"$MONKEYC" -f monkey.jungle -d $DEVICE -o "$OUT" -y "$KEY" -w $RELEASE
echo ""
echo "Built $OUT"
echo "Sideload: copy to the watch's GARMIN/Apps folder (USB/MTP),"
echo "or run in the simulator: $SDK/bin/connectiq && $SDK/bin/monkeydo $OUT $DEVICE"
