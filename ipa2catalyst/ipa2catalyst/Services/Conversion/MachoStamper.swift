//
//  MachoStamper.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation

actor MachoStamper {
    public static func stampVersion(
        machoFiles: [URL],
        done: @escaping (Int, Int) -> Void  // (current, total)
    ) throws {
        let total = machoFiles.count
        for (i, url) in machoFiles.enumerated() {
            print("  [\(i+1)/\(total)] \(url.lastPathComponent)")

            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = [
                "vtool",
                "-set-build-version",
                "6",
                "17.0",
                "17.0",
                "-replace",
                "-output",
                url.path,
                url.path
            ]
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else {
                throw NSError(
                    domain: "MachoStamper",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Failed to patch \(url.lastPathComponent)." : output]
                )
            }
            
            done(i + 1, total)
        }
    }
}
