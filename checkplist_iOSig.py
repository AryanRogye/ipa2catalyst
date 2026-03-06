#!/usr/bin/env python3

import json
import plistlib
import sys

SEPARATOR = "=" * 40

def print_block(title, body, label="Value"):
    print(SEPARATOR)
    print(f"Key: {title}")
    print(f"{label}:")
    for line in str(body).splitlines() or [""]:
        print(f"  {line}")
    print()


def load_plist(path: str):
    with open(path, "rb") as f:
        return plistlib.load(f)


def save_plist(data, path: str):
    with open(path, "wb") as f:
        plistlib.dump(data, f)


def format_value(item: str, value):
    if item in array_items:
        return json.dumps(value, indent=2)
    return value

items = (
    "LSRequiresIPhoneOS",
    "UIDeviceFamily",
    "MinimumOSVersion",
    "CFBundleSupportedPlatforms",
    "DTPlatformName",
    "UIRequiredDeviceCapabilities"
)

array_items = {
    "UIDeviceFamily",
    "CFBundleSupportedPlatforms",
    "UIRequiredDeviceCapabilities",
}


def LSRequiresIPhoneOSSwitch(value: bool, path: str):
    try:
        plist_data = load_plist(path)
        plist_data["LSRequiresIPhoneOS"] = value
        save_plist(plist_data, path)
    except Exception as e:
        print_block("LSRequiresIPhoneOS", str(e), label="Error")
        return

def CFBundleSupportedPlatformsAddPlatform(platform: str, path: str):
    try:
        plist_data = load_plist(path)
        current_platforms = plist_data.get("CFBundleSupportedPlatforms")

        if current_platforms is None:
            current_platforms = []

        if not isinstance(current_platforms, list):
            raise TypeError("CFBundleSupportedPlatforms must be an array")

        if platform in current_platforms:
            return False

        current_platforms.append(platform)
        plist_data["CFBundleSupportedPlatforms"] = current_platforms
        save_plist(plist_data, path)
        return True
    except Exception as e:
        print_block("CFBundleSupportedPlatforms", str(e), label="Error")
        return False

def UIDeviceFamilyAddValue(value: int, path: str):
    try:
        plist_data = load_plist(path)
        current_values = plist_data.get("UIDeviceFamily")

        if current_values is None:
            current_values = []

        if not isinstance(current_values, list):
            raise TypeError("UIDeviceFamily must be an array")

        if value in current_values:
            return False

        current_values.append(value)
        plist_data["UIDeviceFamily"] = current_values
        save_plist(plist_data, path)
        return True
    except Exception as e:
        print_block("UIDeviceFamily", str(e), label="Error")
        return False

def checkIfUIDeviceFamily(item: str, current_value, first_arg: str):
    if item == "UIDeviceFamily":
        if not isinstance(current_value, list):
            print_block(item, "Current value is not an array", label="Error")
            return

        # Auto-apply if '6' (Mac) is missing
        if 6 not in current_value:
            if UIDeviceFamilyAddValue(6, first_arg):
                print_block(item, "Added 6", label="Auto-Updated")
            else:
                print_block(item, "Failed to add 6", label="Error")

def checkIfCFBundleSupportedPlatforms(item: str, current_value, first_arg: str):
    if item == "CFBundleSupportedPlatforms":
        if not isinstance(current_value, list):
            print_block(item, "Current value is not an array", label="Error")
            return

        # Auto-apply if 'MacOSX' is missing
        if "MacOSX" not in current_value:
            if CFBundleSupportedPlatformsAddPlatform("MacOSX", first_arg):
                print_block(item, "Added MacOSX", label="Auto-Updated")
            else:
                print_block(item, "Failed to add MacOSX", label="Error")

def checkIfLSRequiresIPhoneOS(item: str, first_arg: str):
    if item == "LSRequiresIPhoneOS":
        # For Mac execution, we generally want this to be False
        # If it's currently True (or not set), we force it to False
        try:
            plist_data = load_plist(first_arg)
            if plist_data.get("LSRequiresIPhoneOS") is not False:
                LSRequiresIPhoneOSSwitch(False, first_arg)
                print_block(item, "Forced to false", label="Auto-Updated")
        except Exception as e:
            print_block(item, str(e), label="Error")

def run(extras: bool):
    try:
        plist_data = load_plist(first_arg)
    except Exception as e:
        print_block(first_arg, str(e), label="Error")
        sys.exit(1)

    # We are checking each key to see if it exists, if it does we print it
    for item in items:
        if item not in plist_data:
            print_block(item, "Key not found", label="Error")
            continue

        data = plist_data[item]
        formatted_data = format_value(item, data)

        if formatted_data not in ("", None, []):
            print_block(item, formatted_data)
            if extras:
                checkIfLSRequiresIPhoneOS(item, first_arg)
                checkIfCFBundleSupportedPlatforms(item, data, first_arg)
                checkIfUIDeviceFamily(item, data, first_arg)
                # Run again this time to print it
                run(False)

if len(sys.argv) > 1:
    first_arg = sys.argv[1]
    extras = True

    if len(sys.argv) > 2:
        second_arg = sys.argv[2]
        if second_arg == "--no-extras" or second_arg == "-ne" or second_arg == "--ne":
            extras = False

    run(extras)



else:
    print("No arguments provided.")
