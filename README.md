# IPA/App macOS launch toolkit

Utilities for checking plist metadata, extracting entitlements, patching Mach-O platform data, and re-signing app bundles for local testing on macOS.

Use this only with apps you are authorized to test.

## Requirements

- macOS with Xcode command line tools (`xcrun`, `codesign`, `otool`)
- Python 3
- `sudo` access (scripts can move output to `/Applications`)

## Main flow (generalized)

Use `test_generalized.sh` when you want parameterized input instead of hardcoded app paths.

Required args:

- `--method` (`-1` or `-2`)
- `--app` (path to `.app`)
- `--macho` (path to main Mach-O inside app)
- `--info-plist` (path to `Info.plist`)

Optional args:

- `--ipa-zip` (extract app from zip first)
- `--entitlements` (custom entitlements output file)
- `--skip-install` (skip moving to `/Applications` and opening)

Examples:

```bash
./test_generalized.sh \
  --method -1 \
  --app ./NotebookLM_prod.app \
  --macho ./NotebookLM_prod.app/NotebookLM_prod \
  --info-plist ./NotebookLM_prod.app/Info.plist
```

```bash
./test_generalized.sh \
  --method -2 \
  --ipa-zip /path/to/notebooklm.zip \
  --app ./NotebookLM_prod.app \
  --macho ./NotebookLM_prod.app/NotebookLM_prod \
  --info-plist ./NotebookLM_prod.app/Info.plist
```

What this flow does:

1. Optionally unzips IPA and extracts the target `.app`
2. Normalizes plist/signature-related keys (`checkplist_iOSig.py`)
3. Patches Mach-O `LC_BUILD_VERSION` fields
4. Re-signs nested frameworks/extensions (inside-out)
5. Re-signs final app bundle
6. Optionally moves app to `/Applications`
7. Optionally clears xattrs and opens the app

## Devs testing flow (legacy/hardcoded)

`test_from_here.sh` is kept as-is for developer-specific testing and automation.

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

## License

This project is available under the [MIT License](LICENSE).
