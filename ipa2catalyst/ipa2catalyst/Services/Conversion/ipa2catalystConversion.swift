//
//  ipa2catalystConversion.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation

actor ipa2catalystConversion {
    
    let info : DroppedFileInfo
    
    init(info: DroppedFileInfo) {
        self.info = info
    }
    
    func convert(
        createdEntitlements  : @escaping (Bool) -> Void,
        modifiedPlist        : @escaping (Bool) -> Void,
        patchedBinary        : @escaping (Bool) -> Void,
        removedCodeSig       : @escaping (Bool) -> Void,
        collectingMachOs     : @escaping (Int) -> Void,
        doneCollectingMachos : @escaping (Bool) -> Void,
        stampingProgress     : @escaping (Int, Int) -> Void,
        doneStamping         : @escaping (Bool) -> Void,
        libCollecting        : @escaping (Int) -> Void,
        libCollectionDone    : @escaping (Bool) -> Void,
        libSigningProgress   : @escaping (Int, Int) -> Void,
        libSigningDone       : @escaping (Bool) -> Void,
        
        bundleCollecting     : @escaping (Int) -> Void,
        bundleCollectionDone : @escaping (Bool) -> Void,
        bundleSigningProg    : @escaping (Int, Int) -> Void,
        bundleSigningDone    : @escaping (Bool) -> Void,
        
        signedApp            : @escaping (Bool) -> Void,
        
    ) throws {
        /// Create Entitlement File
        let ent = try EntitlementCreator.createEntitlement()
        createdEntitlements(true)

        
        /// Modify Plist
        PlistCore.run(
            path: info.infoPlist.path,
            extras: true
        )
        modifiedPlist(true)
        
        /// Patch Binary Platform
        try BinaryPatcher.patch(
            binary: info.machO,
            infoPlist: info.infoPlist
        )
        patchedBinary(true)
        
        /// Remove Code Signature
        try FileManager.default.removeItem(at: info.codesig)
        removedCodeSig(true)
        
        
        /// Collect MachO's
        let machOs = MachoCollector.collect(
            appURL: info.app,
            done_count: collectingMachOs
        )
        doneCollectingMachos(true)
        
        
        /// Stamp Macho's
        try MachoStamper.stampVersion(
            machoFiles: machOs,
            done: stampingProgress
        )
        doneStamping(true)
        
        
        /// Collect Dynamic Libraries
        let libs = DylibSigner.collect(
            appURL: info.app,
            done: libCollecting
        )
        libCollectionDone(true)
        
        /// Sign those Libs
        try DylibSigner.sign(
            libFiles: libs,
            done: libSigningProgress
        )
        libSigningDone(true)
        
        
        /// Collect Bundles
        let bundles = BundleSigner.collect(
            appURL: info.app,
            done: bundleCollecting
        )
        bundleCollectionDone(true)
        
        /// Sign Bundles
        try BundleSigner.sign(
            bundleDirs: bundles,
            done: bundleSigningProg
        )
        bundleSigningDone(true)
        
        /// Final Sign
        try AppInstaller.finalSign(
            appURL: info.app,
            entitlementsURL: ent
        )
        signedApp(true)
        
        /// Install and Launch
        try AppInstaller.installAndLaunch(
            appURL: info.app
        )
    }
}
