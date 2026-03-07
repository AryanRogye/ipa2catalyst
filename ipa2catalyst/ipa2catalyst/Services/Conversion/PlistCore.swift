//
//  PlistCore.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation

enum PlistCoreError: Error {
    case invalidArrayType(String)
}

/**
 * Function Modifies a Info.plist file to change its values to have
 */
actor PlistCore {
    static let separator = String(repeating: "=", count: 40)
    
    static let items: [String] = [
        "LSRequiresIPhoneOS",
        "UIDeviceFamily",
        "MinimumOSVersion",
        "CFBundleSupportedPlatforms",
        "DTPlatformName",
        "UIRequiredDeviceCapabilities"
    ]
    
    static let arrayItems: Set<String> = [
        "UIDeviceFamily",
        "CFBundleSupportedPlatforms",
        "UIRequiredDeviceCapabilities"
    ]
    
    // MARK: - Printing
    
    static func printBlock(title: String, body: String, label: String = "Value") {
        print(separator)
        print("Key: \(title)")
        print("\(label):")
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            print("  \(line)")
        }
        print()
    }
    
    static func formatValue(item: String, value: Any) -> String {
        if arrayItems.contains(item),
           JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        
        return String(describing: value)
    }
    
    // MARK: - Load / Save
    
    static func loadPlist(at path: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        
        guard let dict = plist as? [String: Any] else {
            return [:]
        }
        
        return dict
    }
    
    static func savePlist(_ plist: [String: Any], to path: String) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    // MARK: - Mutations
    
    static func setLSRequiresIPhoneOS(_ value: Bool, path: String) {
        do {
            var plist = try loadPlist(at: path)
            plist["LSRequiresIPhoneOS"] = value
            try savePlist(plist, to: path)
        } catch {
            printBlock(title: "LSRequiresIPhoneOS", body: error.localizedDescription, label: "Error")
        }
    }
    
    @discardableResult
    static func addPlatform(_ platform: String, path: String) -> Bool {
        do {
            var plist = try loadPlist(at: path)
            let current = plist["CFBundleSupportedPlatforms"]
            
            var platforms: [String]
            if current == nil {
                platforms = []
            } else if let existing = current as? [String] {
                platforms = existing
            } else {
                throw PlistCoreError.invalidArrayType("CFBundleSupportedPlatforms must be an array")
            }
            
            if platforms.contains(platform) {
                return false
            }
            
            platforms.append(platform)
            plist["CFBundleSupportedPlatforms"] = platforms
            try savePlist(plist, to: path)
            return true
        } catch {
            printBlock(title: "CFBundleSupportedPlatforms", body: error.localizedDescription, label: "Error")
            return false
        }
    }
    
    @discardableResult
    static func addDeviceFamily(_ value: Int, path: String) -> Bool {
        do {
            var plist = try loadPlist(at: path)
            let current = plist["UIDeviceFamily"]
            
            var values: [Int]
            if current == nil {
                values = []
            } else if let existing = current as? [Int] {
                values = existing
            } else if let existing = current as? [NSNumber] {
                values = existing.map(\.intValue)
            } else {
                throw PlistCoreError.invalidArrayType("UIDeviceFamily must be an array")
            }
            
            if values.contains(value) {
                return false
            }
            
            values.append(value)
            plist["UIDeviceFamily"] = values
            try savePlist(plist, to: path)
            return true
        } catch {
            printBlock(title: "UIDeviceFamily", body: error.localizedDescription, label: "Error")
            return false
        }
    }
    
    // MARK: - Checks
    
    static func checkIfUIDeviceFamily(item: String, currentValue: Any, path: String) {
        guard item == "UIDeviceFamily" else { return }
        
        let values: [Int]?
        if let ints = currentValue as? [Int] {
            values = ints
        } else if let nums = currentValue as? [NSNumber] {
            values = nums.map(\.intValue)
        } else {
            printBlock(title: item, body: "Current value is not an array", label: "Error")
            return
        }
        
        guard let values else { return }
        
        if !values.contains(6) {
            if addDeviceFamily(6, path: path) {
                printBlock(title: item, body: "Added 6", label: "Auto-Updated")
            } else {
                printBlock(title: item, body: "Failed to add 6", label: "Error")
            }
        }
    }
    
    static func checkIfCFBundleSupportedPlatforms(item: String, currentValue: Any, path: String) {
        guard item == "CFBundleSupportedPlatforms" else { return }
        
        guard let platforms = currentValue as? [String] else {
            printBlock(title: item, body: "Current value is not an array", label: "Error")
            return
        }
        
        if !platforms.contains("MacOSX") {
            if addPlatform("MacOSX", path: path) {
                printBlock(title: item, body: "Added MacOSX", label: "Auto-Updated")
            } else {
                printBlock(title: item, body: "Failed to add MacOSX", label: "Error")
            }
        }
    }
    
    static func checkIfLSRequiresIPhoneOS(item: String, path: String) {
        guard item == "LSRequiresIPhoneOS" else { return }
        
        do {
            let plist = try loadPlist(at: path)
            if (plist["LSRequiresIPhoneOS"] as? Bool) != false {
                setLSRequiresIPhoneOS(false, path: path)
                printBlock(title: item, body: "Forced to false", label: "Auto-Updated")
            }
        } catch {
            printBlock(title: item, body: error.localizedDescription, label: "Error")
        }
    }
    
    // MARK: - Main Core Runner
    
    static func run(path: String, extras: Bool) {
        do {
            let plist = try loadPlist(at: path)
            
            for item in items {
                guard let value = plist[item] else {
                    printBlock(title: item, body: "Key not found", label: "Error")
                    continue
                }
                
                let formatted = formatValue(item: item, value: value)
                
                if !formatted.isEmpty {
                    printBlock(title: item, body: formatted)
                    
                    if extras {
                        checkIfLSRequiresIPhoneOS(item: item, path: path)
                        checkIfCFBundleSupportedPlatforms(item: item, currentValue: value, path: path)
                        checkIfUIDeviceFamily(item: item, currentValue: value, path: path)
                    }
                }
            }
            
            if extras {
                print("Re-reading updated plist...\n")
                run(path: path, extras: false)
            }
            
        } catch {
            printBlock(title: path, body: error.localizedDescription, label: "Error")
        }
    }
}
