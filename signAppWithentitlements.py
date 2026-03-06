#!/usr/bin/env python3
# codesign --force --deep --sign "Apple Development: [Your Name]" --entitlements entitlements.plist YourApp.app

import subprocess
import sys
from file_helpers import isApp

if len(sys.argv) > 3:

    # app
    app = sys.argv[1]

    if not app.endswith(".app"):
        print("No .app detected")
        exit()

    # entitlements
    entitlements = sys.argv[2]

    if not "plist" in entitlements or not "entitlement" in entitlements:
        print("No Entitlements Discovered")
        exit()

    # name
    name = sys.argv[3].strip('"')


    if isApp(app):
        subprocess.run(["codesign", "--force", "--deep", "--sign", f"Apple Development: {name}", "--entitlements", entitlements, app])
    else:
        print("Not an App")
else:
    print("Usage: python signAppWithentitlements.py <app> <entitlements> <name>")
