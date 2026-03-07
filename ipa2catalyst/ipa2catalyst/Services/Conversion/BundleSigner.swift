//
//  BundleSigner.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation

actor BundleSigner {
    public static func collect(
        appURL: URL,
        done: @escaping (Int) -> Void
    ) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: appURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        
        var results: [URL] = []
        
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if [".framework", ".appex"].contains(url.pathExtension) {
                results.append(url)
                done(results.count)
            }
        }
        
        // inside-out: deepest path first (the awk | sort -rn part)
        return results.sorted { $0.pathComponents.count > $1.pathComponents.count }
    }
    
    public static func sign(
        bundleDirs: [URL],
        done: @escaping (Int, Int) -> Void
    ) throws {
        let total = bundleDirs.count
        for (i, url) in bundleDirs.enumerated() {
            print("  [\(i+1)/\(total)] \(url.lastPathComponent)")

            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            process.arguments = ["--force", "--sign", "-", url.path]
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else {
                throw NSError(
                    domain: "BundleSigner",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Failed to sign \(url.lastPathComponent)." : output]
                )
            }
            
            done(i + 1, total)
        }
    }
}
