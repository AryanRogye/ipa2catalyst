//
//  EntitlementCreator.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation

actor EntitlementCreator {
    static let entitlementData =
"""
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.get-task-allow</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.private.security.no-container</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.personal-information.location</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
</dict>
</plist>
"""
    
    static public func createEntitlement() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("entitlements.plist")
        
        let data = Data(entitlementData.utf8)
        
        try data.write(to: url)
        return url
    }
}
