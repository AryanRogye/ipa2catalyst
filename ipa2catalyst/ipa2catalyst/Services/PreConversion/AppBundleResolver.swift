//
//  AppBundleResolver.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//


import ObjectiveC
import Foundation

actor AppBundleResolver {
    private static func detectFileType(_ path: String) -> String {
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue && path.hasSuffix(".app") {
                return "App"
            }
        }
        
        guard let data = FileManager.default.contents(atPath: path) else {
            return "Directory"
        }
        
        let header = data.prefix(16)
        
        if header.starts(with: [0x89,0x50,0x4E,0x47]) {
            return "PNG image"
        }
        
        if header.starts(with: [0xFF,0xD8,0xFF]) {
            return "JPEG image"
        }
        
        if header.starts(with: [0x50,0x4B,0x03,0x04]) {
            return "ZIP / APK / IPA / JAR"
        }
        
        if header.starts(with: [0x7F,0x45,0x4C,0x46]) {
            return "ELF binary"
        }
        
        if header.starts(with: [0xCF,0xFA,0xED,0xFE]) ||
            header.starts(with: [0xFE,0xED,0xFA,0xCF]) {
            return "Mach-O binary"
        }
        
        return "Unknown"
    }
    
    public static func isMachO(_ path: String) -> Bool {
        detectFileType(path) == "Mach-O binary"
    }
    
    public static func findMainMachOAndApp(in url: URL) throws -> (URL?, URL?, URL?, URL?) {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (nil, nil, nil, nil)
        }
        
        for case let currentURL as URL in enumerator {
            let values = try currentURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }
            
            if currentURL.pathExtension == "app" {
                enumerator.skipDescendants()
                
                let infoPlist = currentURL.appendingPathComponent("Info.plist")
                let codeSignature = currentURL.appendingPathComponent("_CodeSignature")
                
                let binary: URL?
                if let bundle = Bundle(url: currentURL) {
                    binary = bundle.executableURL
                } else {
                    binary = nil
                }
                
                let sigURL = fileManager.fileExists(atPath: codeSignature.path) ? codeSignature : nil
                let plistURL = fileManager.fileExists(atPath: infoPlist.path) ? infoPlist : nil
                
                return (binary, currentURL, sigURL, plistURL)
            }
        }
        
        return (nil, nil, nil, nil)
    }
}
