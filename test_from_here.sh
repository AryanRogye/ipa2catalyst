#!/bin/bash
set -e

ZIP=notebooklm
APP=NotebookLM_prod.app
MACHO=NotebookLM_prod
CODE_SIG="$APP"/_CodeSignature
ENTITLEMENTS=entitlements.plist

if [[ -z "$1" ]]; then
  echo "Invalid Arguments ./test_from_here.sh -1 or -2"
  exit
fi
METHOD="$1"
readonly METHOD_ONE="-1"
readonly METHOD_TWO="-2"

if [[ "$METHOD" != "$METHOD_ONE" && "$METHOD" != "$METHOD_TWO" ]]; then
  echo "Invalid Arguments ./test_from_here.sh -1 or -2"
  exit
fi

rm -rf "$ZIP"
rm -rf "$APP"

unzip "$HOME/Downloads/notebooklm.zip" -d "$ZIP"

mv "$ZIP/Payload/$APP" ./

rm -rf "$ZIP"

echo "Running Plist Check"
python checkplist_iOSig.py "$APP"/Info.plist

echo "Checking Method"
if [[ "$METHOD" == "$METHOD_ONE" ]]; then
  echo "Running Method 1"
  python entitlement_ipa.py "$APP"/"$MACHO"
else
  echo "Running Method 2"
  cat <<EOF > "$ENTITLEMENTS"
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

echo "--- Patching binary platform to match Info.plist ---"
python patchBinaryPlatformWithMatchingInfoPlist.py "$APP"

echo "--- Removing code signature ---"
rm -rf "$CODE_SIG"

echo "--- Patching all Mach-O binaries to Platform 6 ---"
MACHO_FILES=()
while IFS= read -r f; do
    MACHO_FILES+=("$f")
done < <(find "$APP" -type f -exec sh -c 'file "$1" | grep -q "Mach-O" && echo "$1"' _ {} \;)
MACHO_TOTAL=${#MACHO_FILES[@]}
for i in "${!MACHO_FILES[@]}"; do
    echo "  [$((i+1))/$MACHO_TOTAL] $(basename "${MACHO_FILES[$i]}")"
    xcrun vtool -set-build-version 6 17.0 17.0 -replace -output "${MACHO_FILES[$i]}" "${MACHO_FILES[$i]}" 2>/dev/null
done

echo "--- Signing loose dylibs and .so files ---"
LIB_FILES=()
while IFS= read -r f; do
    LIB_FILES+=("$f")
done < <(find "$APP" -type f \( -name "*.dylib" -o -name "*.so" \))
LIB_TOTAL=${#LIB_FILES[@]}
for i in "${!LIB_FILES[@]}"; do
    echo "  [$((i+1))/$LIB_TOTAL] $(basename "${LIB_FILES[$i]}")"
    codesign --force --sign - "${LIB_FILES[$i]}"
done

echo "--- Signing .framework bundles (inside-out) ---"
BUNDLE_DIRS=()
while IFS= read -r f; do
    BUNDLE_DIRS+=("$f")
done < <(find "$APP" -type d \( -name "*.framework" -o -name "*.appex" \) | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)
BUNDLE_TOTAL=${#BUNDLE_DIRS[@]}
for i in "${!BUNDLE_DIRS[@]}"; do
    echo "  [$((i+1))/$BUNDLE_TOTAL] $(basename "${BUNDLE_DIRS[$i]}")"
    codesign --force --sign - "${BUNDLE_DIRS[$i]}"
done

echo "--- Final app sign ---"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"
echo "  Done"

echo "Moved App"
rm -rf /Applications/"$APP"
mv "$APP" /Applications/

sudo xattr -cr /Applications/"$APP"
codesign --force --deep --sign - /Applications/"$APP"

# echo "Opening App"
open /Applications/"$APP"
