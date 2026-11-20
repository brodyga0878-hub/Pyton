#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
	printf 'Usage: %s <Godot-exported APK> <signed output APK>\n' "$0" >&2
	exit 2
fi

orbit_input=$1
orbit_output=$2
: "${ANDROID_BUILD_TOOLS:?Set the directory containing apksigner and zipalign}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Set the release keystore}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Set the release key alias}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Set the release keystore password}"
export ORBIT_ANDROID_KEY_PASSWORD="${ORBIT_ANDROID_KEY_PASSWORD:-$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD}"

if [[ ! -f "$orbit_input" || -e "$orbit_output" || -L "$orbit_output" ]]; then
	printf 'Provide an existing input APK and a new output path.\n' >&2
	exit 2
fi

orbit_tool_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
orbit_output_dir="$(dirname -- "$orbit_output")"
mkdir -p -- "$orbit_output_dir"
orbit_temp="$(mktemp -d "$orbit_output_dir/.orbit-apk.XXXXXXXX")"
trap 'rm -rf -- "$orbit_temp"' EXIT

python3 "$orbit_tool_dir/fix_android_provider_authority.py" "$orbit_input" "$orbit_temp/corrected.apk"
"$ANDROID_BUILD_TOOLS/zipalign" -P 16 4 "$orbit_temp/corrected.apk" "$orbit_temp/aligned.apk"
"$ANDROID_BUILD_TOOLS/apksigner" sign \
	--ks "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" \
	--ks-key-alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
	--ks-pass env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD \
	--key-pass env:ORBIT_ANDROID_KEY_PASSWORD \
	--v1-signing-enabled false --v4-signing-enabled false \
	--out "$orbit_temp/signed.apk" "$orbit_temp/aligned.apk"
"$ANDROID_BUILD_TOOLS/zipalign" -c -P 16 4 "$orbit_temp/signed.apk"
"$ANDROID_BUILD_TOOLS/apksigner" verify "$orbit_temp/signed.apk"

ln -T -- "$orbit_temp/signed.apk" "$orbit_output"
