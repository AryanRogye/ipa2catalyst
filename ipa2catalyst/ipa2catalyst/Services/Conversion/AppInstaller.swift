//
//  AppInstaller.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation
import AppKit

actor AppInstaller {
    public static func finalSign(
        appURL: URL,
        entitlementsURL: URL
    ) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = [
            "--force",
            "--deep",
            "--sign",
            "-",
            "--entitlements",
            entitlementsURL.path,
            appURL.path
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AppInstaller",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "codesign failed." : output]
            )
        }
    }
    
    public static func installAndLaunch(
        appURL: URL
    ) throws {
        let dest = URL(fileURLWithPath: "/Applications")
            .appendingPathComponent(appURL.lastPathComponent)

        try runPrivilegedInstall(
            sourcePath: appURL.path,
            appName: appURL.lastPathComponent
        )

        try verifyCodeSignature(appPath: dest.path)
        try launchClean(appPath: dest.path)
    }

    private static func runPrivilegedInstall(sourcePath: String, appName: String) throws {
        let scriptLines = [
            "on run argv",
            "set srcPath to item 1 of argv",
            "set appName to item 2 of argv",
            "set destPath to \"/Applications/\" & appName",
            "set cmd to \"rm -rf \" & quoted form of destPath & \" && mv \" & quoted form of srcPath & \" /Applications/ && xattr -cr \" & quoted form of destPath & \" && find \" & quoted form of destPath & \" -type f \\\\( -name '*.dylib' -o -name '*.so' \\\\) -exec codesign --force --sign - {} \\\\; && find \" & quoted form of destPath & \" -type d \\\\( -name '*.framework' -o -name '*.appex' \\\\) | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- | while IFS= read -r f; do codesign --force --sign - \\\"$f\\\"; done && codesign --force --deep --sign - \" & quoted form of destPath",
            "do shell script cmd with administrator privileges",
            "end run"
        ]

        var arguments = [String]()
        for line in scriptLines {
            arguments.append(contentsOf: ["-e", line])
        }
        arguments.append("--")
        arguments.append(sourcePath)
        arguments.append(appName)

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AppInstaller",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Privileged install failed." : output]
            )
        }
    }

    private static func verifyCodeSignature(appPath: String) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appPath]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AppInstaller",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Signature verification failed." : output]
            )
        }
    }

    private static func launchClean(appPath: String) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [appPath]
        process.standardOutput = pipe
        process.standardError = pipe
        process.environment = sanitizedLaunchEnvironment()

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AppInstaller",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Failed to open installed app." : output]
            )
        }
    }

    private static func sanitizedLaunchEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let blockedPrefixes = [
            "DYLD_",
            "__XPC_DYLD_",
            "IDE",
            "XCODE",
            "LLDB"
        ]
        let blockedKeys = Set([
            "OS_ACTIVITY_DT_MODE",
            "CA_ASSERT_MAIN_THREAD_TRANSACTIONS",
            "CA_DEBUG_TRANSACTIONS"
        ])

        for key in env.keys {
            if blockedKeys.contains(key) || blockedPrefixes.contains(where: { key.hasPrefix($0) }) {
                env.removeValue(forKey: key)
            }
        }

        return env
    }
}
