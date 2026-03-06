# IPA/App macOS launch toolkit

Utilities for checking plist metadata, extracting entitlements, patching Mach-O platform data, and re-signing app bundles for local testing on macOS.

Use this only with apps you are authorized to test.

## Requirements

- macOS with Xcode command line tools (`xcrun`, `codesign`, `otool`)
- Python 3
- `sudo` access (script moves output to `/Applications`)
- Source IPA at `/path/to/notebooklm.zip` (edit script if different)

## Main flow

Run:

```bash
./test_from_here.sh -1
```

or

```bash
./test_from_here.sh -2
```

Mode details:

- `-1`: extract entitlements from the main Mach-O using `entitlement_ipa.py`
- `-2`: generate `entitlements.plist` from the script template

What the script does:

1. Unzips IPA and extracts the `.app`
2. Normalizes plist/signature-related keys (`checkplist_iOSig.py`)
3. Patches Mach-O `LC_BUILD_VERSION` fields
4. Re-signs nested frameworks/extensions (inside-out)
5. Re-signs final app bundle
6. Moves app to `/Applications`
7. Clears xattrs and opens the app

## Individual scripts

```bash
python checkplist_iOSig.py some_app.app/Info.plist
```

```bash
python entitlement_ipa.py some_app.app/some_macho
```

```bash
python patchBinaryPlatformWithMatchingInfoPlist.py some_app.app
```

```bash
python signAppWithentitlements.py some_app.app entitlements.plist "Signing Name"
```

## Verify state

```bash
codesign --verify --deep --strict --verbose=6 Some.app
```

```bash
codesign -d --entitlements - Some.app
```

```bash
spctl -a -vv Some.app
```

## Common issues

- `zsh: killed` on direct binary launch:
  nested code objects are usually not signed correctly, or launch policy blocked execution.
- `open ... Launch failed` / `spawn failed`:
  retry after signing, then approve in macOS Privacy & Security if prompted.
- `codesign --verify` passes but app still blocked:
  that only validates signature consistency; macOS policy/Gatekeeper may still reject launch.

## Public release note

If you make this repo public, document ownership/authorization expectations clearly and avoid shipping private app assets or credentials.
