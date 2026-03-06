#!/usr/bin/env python3

import sys
import subprocess
from file_helpers import isMacho, create_entitlements
from xml.dom.minidom import parseString
import xml.etree.ElementTree as ET
import plistlib


# <key>com.apple.security.app-sandbox</key>
# <true/>
# <key>com.apple.security.personal-information.location</key>
# <true/>
# <key>com.apple.private.apple-78</key>
# <true/>

def doesXmlHaveRequiredEntitlements(xml: str) -> bool:
    if "com.apple.security.app-sandbox" not in xml:
        return False
    if "com.apple.security.personal-information.location" not in xml:
        return False
    if "com.apple.private.apple-78" not in xml:
        return False
    return True

def removeDuplicateKeys(xml) -> str:
    xml_string = xml
    data = plistlib.loads(xml_string.encode())
    return plistlib.dumps(data).decode()


# Returns the modified XML
def add_macOS_entitlements(xml: str) -> str:
    root = ET.fromstring(xml)
    dict_node = root.find("dict")

    existing_keys = [elem.text for elem in dict_node.findall("key")]

    def add_bool_key(name: str):
        if name not in existing_keys:
            key = ET.SubElement(dict_node, "key")
            key.text = name
            ET.SubElement(dict_node, "true")

    # add_bool_key("com.apple.security.app-sandbox")
    # add_bool_key("com.apple.security.personal-information.location")
    # Testing with this off maybe turn on again
    # add_bool_key("com.apple.private.apple-78")

    return ET.tostring(root, encoding="unicode")

def get_entitlements(path: str):
    # Added --display to be more explicit
    r = subprocess.run(
        ["codesign", "--display", "--entitlements", "-", "--xml", path],
        capture_output=True,
        text=True
    )

    if r.returncode == 0:
        # Some versions/environments flip between stdout and stderr
        output = r.stdout or r.stderr
        return output if output.strip() else None
    return None

if len(sys.argv) > 1:
    arg = sys.argv[1]
    if not isMacho(arg):
        print("is not a Mach-O binary Skipping")
        exit()

    if get_entitlements(arg) is None:
        print("No entitlements found")
        exit()

    print("===========================================")
    print("Found Entitlements:")
    print("===========================================")

    raw_xml = get_entitlements(arg)
    dom = parseString(raw_xml)
    print(dom.toprettyxml())
    print("===========================================")

    new_xml = add_macOS_entitlements(raw_xml)

    print("Entitlement Injected:")
    print("===========================================")
    print(parseString(new_xml).toprettyxml())
    print("===========================================")

    clean_xml = removeDuplicateKeys(new_xml)

    create_entitlements(clean_xml)
else:
    print("No argument provided.")
