#!/bin/sh
# New reconstruction build wrapper. A release engine with a TEST key is not a
# production-signed release. The separate package preserves any old installation.
set -eu
SCRIPT_PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_PROJECT=${STARFRONTIER_PROJECT_ROOT:-$SCRIPT_PROJECT}
TOOLCHAIN_ROOT=${STARFRONTIER_TOOLCHAIN_ROOT:-/workspace/toolchains}
BUILD_MODE=${1:---candidate}
case "$BUILD_MODE" in
    --candidate|--debug) ;;
    *) echo 'Usage: tools/build_android.sh [--candidate|--debug]' >&2; exit 2 ;;
esac
if [ ! -f "$BUILD_PROJECT/project.godot" ] || [ ! -f "$BUILD_PROJECT/export_presets.cfg" ]; then
    echo 'Godot project or Android export preset is missing.' >&2
    exit 1
fi
for BUILD_REQUIRED in "$TOOLCHAIN_ROOT/jdk17/bin/java" "$TOOLCHAIN_ROOT/android-sdk/build-tools/36.0.0/apksigner" "$TOOLCHAIN_ROOT/godot-data/godot/export_templates/4.6.3.stable/android_release.apk"; do
    if [ ! -f "$BUILD_REQUIRED" ]; then
        echo 'Toolchain missing. Run: python3 tools/setup_android_toolchain.py' >&2
        exit 1
    fi
done
export JAVA_HOME="$TOOLCHAIN_ROOT/jdk17"
export PATH="$JAVA_HOME/bin:$TOOLCHAIN_ROOT/android-sdk/platform-tools:$PATH"
export XDG_DATA_HOME="$TOOLCHAIN_ROOT/godot-data"
export XDG_CONFIG_HOME="$TOOLCHAIN_ROOT/godot-config"
export XDG_CACHE_HOME="$TOOLCHAIN_ROOT/cache"
export ANDROID_USER_HOME="$TOOLCHAIN_ROOT/android-user"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$TOOLCHAIN_ROOT/keys/starfrontier-rebuild-test.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=starfrontier-rebuild-test
# Publicly documented local TEST password; no owner production key is used.
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
if [ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then
    echo 'Rebuild TEST keystore missing; rerun the toolchain installer.' >&2
    exit 1
fi
mkdir -p "$BUILD_PROJECT/build"
# Exclude generated test projects, logs and screenshots from the editor scan.
# The export filter alone runs after some resource/dependency discovery.
: > "$BUILD_PROJECT/build/.gdignore"
BUILD_OUTPUT="$BUILD_PROJECT/build/starfrontier-rebuild-arm64-alpha.apk"
BUILD_LOG="$BUILD_PROJECT/build/android-export.log"
rm -f "$BUILD_OUTPUT"
if [ "$BUILD_MODE" = --debug ]; then BUILD_EXPORT_FLAG=--export-debug; else BUILD_EXPORT_FLAG=--export-release; fi
if godot --headless --path "$BUILD_PROJECT" "$BUILD_EXPORT_FLAG" Android "$BUILD_OUTPUT" > "$BUILD_LOG" 2>&1; then
    cat "$BUILD_LOG"
else
    BUILD_STATUS=$?
    cat "$BUILD_LOG"
    exit "$BUILD_STATUS"
fi
python3 - "$BUILD_LOG" "$BUILD_OUTPUT" <<'PY'
from pathlib import Path
import re,sys
log=Path(sys.argv[1]).read_text(errors='replace')
if re.search(r'^\s*(SCRIPT ERROR:|ERROR:)|ObjectDB instances leaked|RID allocations of type',log,re.M):
    raise SystemExit('Android export reported engine errors; artifact rejected')
apk=Path(sys.argv[2])
if not apk.is_file() or apk.stat().st_size<1000000:
    raise SystemExit('Android export did not produce a fresh APK')
print('Fresh Android APK:',apk)
PY
