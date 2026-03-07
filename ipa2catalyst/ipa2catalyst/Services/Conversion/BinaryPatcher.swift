//
//  BinaryPatcher.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation

actor BinaryPatcher {
    static func patch(binary: URL, infoPlist: URL) throws {
        // 1. Read Plist for minimum OS version
        let plistData = try Data(contentsOf: infoPlist)
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        
        let plistMinOS = (plist?["LSMinimumSystemVersion"] as? String) ?? (plist?["MinimumOSVersion"] as? String)
        
        // 2. Parse current LC_BUILD_VERSION using xcrun vtool
        let showBuildOutput = try run(executable: "xcrun", args: ["vtool", "-show-build", binary.path])
        
        let minosRegex = try NSRegularExpression(pattern: "\\bminos\\s+([0-9]+(?:\\.[0-9]+){1,2})")
        let sdkRegex = try NSRegularExpression(pattern: "\\bsdk\\s+([0-9]+(?:\\.[0-9]+){1,2})")
        
        let range = NSRange(showBuildOutput.startIndex..., in: showBuildOutput)
        
        var currentMinos: String?
        if let match = minosRegex.firstMatch(in: showBuildOutput, range: range), let matchRange = Range(match.range(at: 1), in: showBuildOutput) {
            currentMinos = String(showBuildOutput[matchRange])
        }
        
        var currentSDK: String?
        if let match = sdkRegex.firstMatch(in: showBuildOutput, range: range), let matchRange = Range(match.range(at: 1), in: showBuildOutput) {
            currentSDK = String(showBuildOutput[matchRange])
        }
        
        // 3. Resolve target versions (using platform "6" for Mac Catalyst as in your python script)
        let targetPlatform = "6"
        let finalMinOS = plistMinOS ?? currentMinos ?? "11.0"
        let finalSDK = currentSDK ?? finalMinOS
        
        // 4. Run xcrun vtool to patch to a temp file
        let tempBinary = binary.deletingLastPathComponent().appendingPathComponent("patched_\(binary.lastPathComponent)")
        
        let patchArgs = [
            "vtool",
            "-set-build-version", targetPlatform, finalMinOS, finalSDK,
            "-replace",
            "-output", tempBinary.path,
            binary.path
        ]
        
        _ = try run(executable: "xcrun", args: patchArgs)
        
        // 5. Replace original binary with patched binary
        try FileManager.default.removeItem(at: binary)
        try FileManager.default.moveItem(at: tempBinary, to: binary)
    }
    
    // Helper to execute shell commands natively
    private static func run(executable: String, args: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + args
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        guard process.terminationStatus == 0 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown vtool error"
            throw NSError(domain: "BinaryPatcherError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
}
