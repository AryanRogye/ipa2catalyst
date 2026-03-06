# This contains scripts so we can do .ipa/.app tricks fast


## This modifies the plist to contain signatures to run on macOS
python checkplist_iOSig.py some_app.app/Info.plist

## This Grabs the entitlement from the Mach-O Binary
python entitlement_ipa.py some_app.app/ints_macho
| Then Creates a entitlements.plist

## This patches the Mach-O LC_BUILD_VERSION to match Info.plist platform data
python patchBinaryPlatformWithMatchingInfoPlist.py some_app.app
| Run this before signing so Info.plist, entitlements, and Mach-O agree on platform

## This re-signs the app with your entitlements
python signAppWithentitlements.py some_app.app entitlements.plist "Name"
| making sure name is the name of your apple developer account
