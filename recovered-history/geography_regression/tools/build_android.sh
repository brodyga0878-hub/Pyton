#!/bin/sh
set -eu
APP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -d /workspace/toolchains/godot-data ]; then
    export XDG_DATA_HOME=/workspace/toolchains/godot-data
    export XDG_CONFIG_HOME=/workspace/toolchains/godot-config
    export XDG_CACHE_HOME=/workspace/toolchains/cache
    export ANDROID_USER_HOME=/workspace/toolchains/android-user
fi
mkdir -p "$APP_ROOT/build"
if [ "${1:-}" = "--candidate" ]; then
    # Release engine/template, same TEST certificate as earlier APKs for in-place updates.
    # This is deliberately not a production signing key.
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:=/workspace/toolchains/keys/android-debug.keystore}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:=androiddebugkey}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:=android}"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
    if [ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then
        echo 'Configure the Android test signing key before building a candidate.' >&2
        exit 1
    fi
    godot --headless --path "$APP_ROOT" --export-release Android "$APP_ROOT/build/starfrontier-arm64-rc.apk"
else
    godot --headless --path "$APP_ROOT" --export-debug Android "$APP_ROOT/build/starfrontier-arm64-debug.apk"
fi
