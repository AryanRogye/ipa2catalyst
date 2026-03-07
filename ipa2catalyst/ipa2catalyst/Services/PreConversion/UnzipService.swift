//
//  UnzipService.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import ZIPFoundation
import Foundation

struct DroppedFileInfo {
    let codesig   : URL
    let app       : URL
    let machO     : URL
    let infoPlist : URL
}

actor UnzipService {
    private let analysesDirectoryName = "Analyses"
    
    public func unzip(file: URL) async throws -> DroppedFileInfo? {
        let fm = FileManager.default
        let destinationRoot = try analysesRootDirectory(fileManager: fm)
        let destinationDirectory = destinationRoot
            .appendingPathComponent(outputDirectoryName(for: file), isDirectory: true)
        
        if fm.fileExists(atPath: destinationDirectory.path) {
            try fm.removeItem(at: destinationDirectory)
        }
        
        try fm.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try fm.unzipItem(at: file, to: destinationDirectory)
        
        let (machO, app, codesig, plist) = try AppBundleResolver.findMainMachOAndApp(in: destinationDirectory)
        
        if let machO, let app, let codesig, let plist {
            return DroppedFileInfo(
                codesig: codesig,
                app: app,
                machO: machO,
                infoPlist: plist
            )
        }
        return nil
    }

    private func analysesRootDirectory(fileManager: FileManager) throws -> URL {
        let appSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let bundleFolder = (Bundle.main.bundleIdentifier ?? "ipa2catalyst")
            .replacingOccurrences(of: ".", with: "-")

        let analysesRoot = appSupportDirectory
            .appendingPathComponent(bundleFolder, isDirectory: true)
            .appendingPathComponent(analysesDirectoryName, isDirectory: true)

        try fileManager.createDirectory(at: analysesRoot, withIntermediateDirectories: true)
        return analysesRoot
    }

    private func outputDirectoryName(for file: URL) -> String {
        let baseName = file.deletingPathExtension().lastPathComponent
        return "\(baseName)-\(UUID().uuidString.prefix(8))"
    }
}
