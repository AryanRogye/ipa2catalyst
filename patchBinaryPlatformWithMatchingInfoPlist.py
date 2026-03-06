#!/usr/bin/env python3

import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

from file_helpers import isApp, isMacho


def run_capture(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def load_plist(path: str):
    with open(path, "rb") as f:
        return plistlib.load(f)


def find_app_binary_from_plist(app_path: str, plist_data) -> str:
    executable = plist_data.get("CFBundleExecutable")
    if not executable:
        raise ValueError("CFBundleExecutable is missing from Info.plist")

    binary_path = os.path.join(app_path, executable)
    if not os.path.exists(binary_path):
        raise FileNotFoundError(f"CFBundleExecutable target not found: {binary_path}")
    return binary_path


def map_platform_name(name: str):
    mapping = {
        "MacOSX": "maccatalyst",
        "iPhoneOS": "ios",
        "iPhoneSimulator": "iossim",
        "AppleTVOS": "tvos",
        "AppleTVSimulator": "tvos",
        "WatchOS": "watchos",
        "WatchSimulator": "watchossim",
        "XROS": "visionos",
        "XRSimulator": "visionossim",
    }
    return mapping.get(name)


def choose_target_platform(plist_data) -> str:
    platforms = plist_data.get("CFBundleSupportedPlatforms")
    if isinstance(platforms, list):
        # Map them using your updated map_platform_name (which now has mac-catalyst)
        mapped = [map_platform_name(p) for p in platforms if map_platform_name(p)]
        
        # KEY FIX: If it's an iOS app running on Mac, force mac-catalyst
        if "ios" in mapped and "mac-catalyst" in mapped:
            return "mac-catalyst"
            
        if len(mapped) >= 1:
            return mapped[0]

    # Fallback logic
    dt_platform_name = str(plist_data.get("DTPlatformName", "")).lower()
    if dt_platform_name == "iphoneos" or dt_platform_name == "macosx":
         return "mac-catalyst"
         
    raise ValueError("Could not determine target platform from Info.plist")

# def choose_target_platform(plist_data) -> str:
#     platforms = plist_data.get("CFBundleSupportedPlatforms")
#     if isinstance(platforms, list):
#         mapped = [map_platform_name(p) for p in platforms if map_platform_name(p)]
#         if len(mapped) == 1:
#             return mapped[0]
#
#         if len(mapped) > 1:
#             # Typical patched iOS app flow: once LSRequiresIPhoneOS is false and
#             # MacOSX is present, the binary should also be macOS for consistency.
#             if "macos" in mapped and plist_data.get("LSRequiresIPhoneOS") is False:
#                 return "macos"
#
#             dt_platform_name = str(plist_data.get("DTPlatformName", "")).lower()
#             dt_map = {
#                 "macosx": "macos",
#                 "iphoneos": "ios",
#                 "iphonesimulator": "iossim",
#                 "appletvos": "tvos",
#                 "watchos": "watchos",
#                 "xros": "visionos",
#             }
#             candidate = dt_map.get(dt_platform_name)
#             if candidate and candidate in mapped:
#                 return candidate
#
#             return mapped[0]
#
#     dt_platform_name = str(plist_data.get("DTPlatformName", "")).lower()
#     fallback_map = {
#         "macosx": "macos",
#         "iphoneos": "ios",
#         "iphonesimulator": "iossim",
#         "appletvos": "tvos",
#         "watchos": "watchos",
#         "xros": "visionos",
#     }
#     if dt_platform_name in fallback_map:
#         return fallback_map[dt_platform_name]
#
#     raise ValueError("Could not determine target platform from Info.plist")


def parse_current_build_versions(binary_path: str):
    r = run_capture(["xcrun", "vtool", "-show-build", binary_path])
    if r.returncode != 0:
        details = (r.stderr or r.stdout or "").strip()
        raise RuntimeError(f"Unable to read current LC_BUILD_VERSION: {details}")

    text = r.stdout
    minos_match = re.search(r"\bminos\s+([0-9]+(?:\.[0-9]+){1,2})", text)
    sdk_match = re.search(r"\bsdk\s+([0-9]+(?:\.[0-9]+){1,2})", text)

    minos = minos_match.group(1) if minos_match else None
    sdk = sdk_match.group(1) if sdk_match else None
    return minos, sdk, text


def is_version_like(value) -> bool:
    if not isinstance(value, str):
        return False
    return re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", value.strip()) is not None


def choose_versions(plist_data, target_platform: str, current_minos: str, current_sdk: str):
    if target_platform == "macos":
        plist_minos = plist_data.get("LSMinimumSystemVersion")
        if not is_version_like(plist_minos):
            plist_minos = plist_data.get("MinimumOSVersion")
        default_minos = "11.0"
    else:
        plist_minos = plist_data.get("MinimumOSVersion")
        default_minos = "12.0"

    minos = None
    if is_version_like(plist_minos):
        minos = plist_minos.strip()
    elif is_version_like(current_minos):
        minos = current_minos.strip()
    else:
        minos = default_minos

    if is_version_like(current_sdk):
        sdk = current_sdk.strip()
    else:
        sdk = minos

    return minos, sdk


def patch_binary_platform(binary_path: str, target_platform: str, minos: str, sdk: str):
    binary_dir = os.path.dirname(os.path.abspath(binary_path))
    fd, temp_path = tempfile.mkstemp(prefix="patched_", dir=binary_dir)
    os.close(fd)

    try:
        cmd = [
            "xcrun", "vtool",
            "-set-build-version", target_platform, minos, sdk,
            "-replace",
            "-output", temp_path,
            binary_path,
        ]
        r = run_capture(cmd)
        if r.returncode != 0:
            details = (r.stderr or r.stdout or "").strip()
            raise RuntimeError(f"vtool failed: {details}")

        binary_mode = os.stat(binary_path).st_mode
        os.chmod(temp_path, binary_mode)
        os.replace(temp_path, binary_path)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


def resolve_inputs(argv):
    if len(argv) < 2:
        print("Usage: python patchBinaryPlatformWithMatchingInfoPlist.py <app_or_binary> [info_plist]")
        sys.exit(1)

    first_arg = argv[1]

    if isApp(first_arg):
        app_path = first_arg
        plist_path = os.path.join(app_path, "Info.plist")
        if not os.path.exists(plist_path):
            raise FileNotFoundError(f"Info.plist not found: {plist_path}")
        plist_data = load_plist(plist_path)
        binary_path = find_app_binary_from_plist(app_path, plist_data)
        return binary_path, plist_path, plist_data

    binary_path = first_arg
    if not isMacho(binary_path):
        raise ValueError("First argument must be an .app bundle or Mach-O binary")

    if len(argv) > 2:
        plist_path = argv[2]
    else:
        app_dir = os.path.dirname(os.path.abspath(binary_path))
        plist_path = os.path.join(app_dir, "Info.plist")

    if not os.path.exists(plist_path):
        raise FileNotFoundError(f"Info.plist not found: {plist_path}")

    plist_data = load_plist(plist_path)
    return binary_path, plist_path, plist_data


def main():
    try:
        binary_path, plist_path, plist_data = resolve_inputs(sys.argv)

        if not isMacho(binary_path):
            print("Resolved binary is not Mach-O. Skipping")
            sys.exit(1)

        current_minos, current_sdk, before_text = parse_current_build_versions(binary_path)
        # target_platform = choose_target_platform(plist_data)
        target_platform = "6"
        minos, sdk = choose_versions(plist_data, target_platform, current_minos, current_sdk)

        print("===========================================")
        print(f"Info.plist: {plist_path}")
        print(f"Binary: {binary_path}")
        print(f"Target platform from Info.plist: {target_platform}")
        print(f"Using minos: {minos}")
        print(f"Using sdk: {sdk}")
        print("===========================================")
        print("Current LC_BUILD_VERSION:")
        print(before_text.strip())
        print("===========================================")

        patch_binary_platform(binary_path, target_platform, minos, sdk)

        _, _, after_text = parse_current_build_versions(binary_path)
        print("Patched LC_BUILD_VERSION:")
        print(after_text.strip())
        print("===========================================")
        print("Patch complete. Run signing next.")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
