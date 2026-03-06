#!/usr/bin/env python3

import os

def detect_file_type(path) -> str:
    if os.path.isdir(path) and path.endswith(".app"):
        return "App"

    try:
        with open(path, "rb") as f:
            header = f.read(16)
    except IsADirectoryError:
        return "Directory"

    if header.startswith(b"\x89PNG"):
        return "PNG image"
    if header.startswith(b"\xFF\xD8\xFF"):
        return "JPEG image"
    if header.startswith(b"PK\x03\x04"):
        return "ZIP / APK / IPA / JAR"
    if header.startswith(b"\x7fELF"):
        return "ELF binary"
    if header.startswith(b"\xcf\xfa\xed\xfe") or header.startswith(b"\xfe\xed\xfa\xcf"):
        return "Mach-O binary"

    return "Unknown"

def isMacho(path: str):
    return detect_file_type(path) == "Mach-O binary"

def isApp(path: str):
    return detect_file_type(path) == "App"

def create_entitlements(xml: str):
    with open("entitlements.plist", "w") as f:
        f.write(xml)
