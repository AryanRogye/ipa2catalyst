//
//  MachoCollector.swift
//  ipa2catalyst
//
//  Created by Aryan Rogye on 3/7/26.
//

import Foundation

/// Function Goes Through all the MachO's in a .app
actor MachoCollector {
    public static func collect(
        appURL: URL,
        done_count: @escaping (Int) -> Void
    ) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: appURL, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        
        var results: [URL] = []
        
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            guard AppBundleResolver.isMachO(url.path) else { continue }
            results.append(url)
            done_count(results.count)
        }
        
        return results
    }
}
