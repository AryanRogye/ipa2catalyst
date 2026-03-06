#!/bin/bash
set -euo pipefail

METHOD=""
APP_PATH=""
MACHO_PATH=""
INFO_PLIST=""
IPA_ZIP=""
ENTITLEMENTS_PATH="entitlements.plist"
SKIP_INSTALL=0

usage() {
  cat <<'EOF'
Usage:
  ./test_generalized.sh \
    --method -1|-2 \
    --app /path/to/AppName.app \
    --macho /path/to/AppName.app/AppBinary \
    --info-plist /path/to/AppName.app/Info.plist \
    [--ipa-zip /path/to/file.zip] \
    [--entitlements /path/to/entitlements.plist] \
    [--skip-install]

Required:
  --method       -1 (extract entitlements) or -2 (template entitlements)
  --app          .app bundle path (used directly, or as target name when --ipa-zip is provided)
  --macho        main Mach-O binary path inside the app
  --info-plist   Info.plist path for plist normalization

Optional:
  --ipa-zip      Zip containing Payload/<AppName>.app; extracted into current directory
  --entitlements Output entitlements plist path (default: entitlements.plist)
  --skip-install Do not move app to /Applications or open it
EOF
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Error: file not found: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [[ ! -d "$1" ]]; then
    echo "Error: directory not found: $1" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)
      METHOD="${2:-}"
      shift 2
      ;;
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --macho)
      MACHO_PATH="${2:-}"
      shift 2
      ;;
    --info-plist)
      INFO_PLIST="${2:-}"
      shift 2
      ;;
    --ipa-zip)
      IPA_ZIP="${2:-}"
      shift 2
      ;;
    --entitlements)
      ENTITLEMENTS_PATH="${2:-}"
      shift 2
      ;;
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$METHOD" || -z "$APP_PATH" || -z "$MACHO_PATH" || -z "$INFO_PLIST" ]]; then
  echo "Error: --method, --app, --macho, and --info-plist are required." >&2
  usage
  exit 1
fi

if [[ "$METHOD" != "-1" && "$METHOD" != "-2" ]]; then
  echo "Error: --method must be -1 or -2." >&2
  exit 1
fi

if [[ -n "$IPA_ZIP" ]]; then
  require_file "$IPA_ZIP"
  APP_BASENAME="$(basename "$APP_PATH")"
  TEMP_DIR="$(mktemp -d)"

  echo "Extracting app from zip: $IPA_ZIP"
  unzip -q "$IPA_ZIP" -d "$TEMP_DIR"

  EXTRACTED_APP="$TEMP_DIR/Payload/$APP_BASENAME"
  require_dir "$EXTRACTED_APP"

  rm -rf "$APP_BASENAME"
  mv "$EXTRACTED_APP" "./$APP_BASENAME"

  APP_PATH="./$APP_BASENAME"
  MACHO_PATH="$APP_PATH/$(basename "$MACHO_PATH")"
  INFO_PLIST="$APP_PATH/$(basename "$INFO_PLIST")"

  rm -rf "$TEMP_DIR"
fi

require_dir "$APP_PATH"
require_file "$MACHO_PATH"
require_file "$INFO_PLIST"

CODE_SIG="$APP_PATH/_CodeSignature"

echo "Running plist check"
python checkplist_iOSig.py "$INFO_PLIST"

if [[ "$METHOD" == "-1" ]]; then
  echo "Method -1: extracting entitlements from main Mach-O"
  python entitlement_ipa.py "$MACHO_PATH"
else
  echo "Method -2: writing template entitlements to $ENTITLEMENTS_PATH"
  cat <<EOF > "$ENTITLEMENTS_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
  <key>com.apple.security.get-task-allow</key>
  <true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
  <true/>
  <key>com.apple.private.security.no-container</key>
  <true/>
  <key>com.apple.security.device.audio-input</key>
  <true/>
  <key>com.apple.security.personal-information.location</key>
  <true/>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
</dict>
</plist>
EOF
fi

echo "Patching binary platform to match Info.plist"
python patchBinaryPlatformWithMatchingInfoPlist.py "$APP_PATH"

echo "Removing code signature"
rm -rf "$CODE_SIG"

echo "Patching all Mach-O binaries"
MACHO_FILES=()
while IFS= read -r f; do
  MACHO_FILES+=("$f")
done < <(find "$APP_PATH" -type f -exec sh -c 'file "$1" | grep -q "Mach-O" && echo "$1"' _ {} \;)

MACHO_TOTAL=${#MACHO_FILES[@]}
for i in "${!MACHO_FILES[@]}"; do
  echo "  [$((i + 1))/$MACHO_TOTAL] $(basename "${MACHO_FILES[$i]}")"
  xcrun vtool -set-build-version 6 17.0 17.0 -replace -output "${MACHO_FILES[$i]}" "${MACHO_FILES[$i]}" 2>/dev/null
done

echo "Signing loose dylibs and .so files"
LIB_FILES=()
while IFS= read -r f; do
  LIB_FILES+=("$f")
done < <(find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.so" \))

LIB_TOTAL=${#LIB_FILES[@]}
for i in "${!LIB_FILES[@]}"; do
  echo "  [$((i + 1))/$LIB_TOTAL] $(basename "${LIB_FILES[$i]}")"
  codesign --force --sign - "${LIB_FILES[$i]}"
done

echo "Signing frameworks and extensions (inside-out)"
BUNDLE_DIRS=()
while IFS= read -r f; do
  BUNDLE_DIRS+=("$f")
done < <(find "$APP_PATH" -type d \( -name "*.framework" -o -name "*.appex" \) | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

BUNDLE_TOTAL=${#BUNDLE_DIRS[@]}
for i in "${!BUNDLE_DIRS[@]}"; do
  echo "  [$((i + 1))/$BUNDLE_TOTAL] $(basename "${BUNDLE_DIRS[$i]}")"
  codesign --force --sign - "${BUNDLE_DIRS[$i]}"
done

echo "Final app sign"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_PATH" "$APP_PATH"

if [[ "$SKIP_INSTALL" -eq 1 ]]; then
  echo "Skipping /Applications install and open"
  exit 0
fi

APP_BASENAME="$(basename "$APP_PATH")"
echo "Moving app to /Applications/$APP_BASENAME"
rm -rf "/Applications/$APP_BASENAME"
mv "$APP_PATH" "/Applications/"

sudo xattr -cr "/Applications/$APP_BASENAME"
codesign --force --deep --sign - "/Applications/$APP_BASENAME"

open "/Applications/$APP_BASENAME"
