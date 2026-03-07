//
//  DropFileAnalyzer.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import SwiftUI
import UniformTypeIdentifiers

enum DropFileAnalyzerError: Error {
    case onlyOneFileCanBeDropped
    case errorRenamingIpaExtension
    case isNotAnIpaOrZipFile
}

/**
 Handles drag-and-drop file input for the app.
 
 This actor processes files dropped by the user and ensures that only a single
 valid archive is accepted. It supports `.zip` and `.ipa` files.
 
 If an `.ipa` file is dropped, it is copied and renamed to a `.zip` file so it
 can be processed like a standard ZIP archive. The function then returns the
 URL of the ZIP file for further extraction or analysis.
 
 Returns:
 - `(Bool, URL?)`
 - `Bool` indicates whether a valid archive was detected.
 - `URL` points to the ZIP file that should be processed.
 
 Throws:
 - `onlyOneFileCanBeDropped` if multiple files are dropped.
 - `errorRenamingIpaExtension` if the `.ipa` file could not be copied/renamed.
 - `isNotAnIpaOrZipFile` if the dropped file is not supported.
 
 Usually just ran at the start
 */
actor DropFileAnalyzer {
    
    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = {
                    if let data = item as? Data {
                        return URL(dataRepresentation: data, relativeTo: nil)
                    }
                    if let droppedURL = item as? URL {
                        return droppedURL
                    }
                    if let nsURL = item as? NSURL {
                        return nsURL as URL
                    }
                    return nil
                }()
                
                continuation.resume(returning: url)
            }
        }
    }
    
    func handleInitialDrop(providers: [NSItemProvider]) async throws -> (Bool, URL?) {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        
        guard !fileProviders.isEmpty else { return (false, nil) }
        
        if fileProviders.count > 1 {
            throw DropFileAnalyzerError.onlyOneFileCanBeDropped
        }
        
        for provider in fileProviders {
            guard let fileURL = await loadURL(from: provider) else { continue }
            
            let ext = fileURL.pathExtension.lowercased()
            
            if ext == "zip" {
                return (true, fileURL)
            } else if ext == "ipa" {
                let zipURL = fileURL.deletingPathExtension().appendingPathExtension("zip")
                
                do {
                    if FileManager.default.fileExists(atPath: zipURL.path) {
                        try FileManager.default.removeItem(at: zipURL)
                    }
                    
                    try FileManager.default.copyItem(at: fileURL, to: zipURL)
                    return (true, zipURL)
                } catch {
                    throw DropFileAnalyzerError.errorRenamingIpaExtension
                }
            } else {
                throw DropFileAnalyzerError.isNotAnIpaOrZipFile
            }
        }
        
        return (false, nil)
    }

}
