//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

protocol SharedEmojiPackSourceProtocol {
    /// The JSON content of the image pack shared with every user, or `nil` when none is configured or it can't be downloaded.
    func fetch() async -> String?
}

/// Downloads the image pack shared with every user from `AppSettings.sharedEmojiPackURL`.
class SharedEmojiPackSource: SharedEmojiPackSourceProtocol {
    typealias DataLoader = (URL) async throws -> Data
    
    nonisolated enum DownloadError: Error {
        case unexpectedResponse
    }
    
    private static let cacheDuration: TimeInterval = 10 * 60
    
    private let url: URL?
    private let dataLoader: DataLoader
    private let now: () -> Date
    
    private var cachedContent: String?
    private var cachedDate = Date.distantPast
    
    init(url: URL?,
         dataLoader: @escaping DataLoader = SharedEmojiPackSource.download,
         now: @escaping () -> Date = Date.init) {
        self.url = url
        self.dataLoader = dataLoader
        self.now = now
    }
    
    func fetch() async -> String? {
        guard let url else { return nil }
        
        if let cachedContent, now().timeIntervalSince(cachedDate) < Self.cacheDuration {
            return cachedContent
        }
        
        do {
            let content = try await String(decoding: dataLoader(url), as: UTF8.self)
            cachedContent = content
            cachedDate = now()
            return content
        } catch {
            // Keep offering the last known pack while the server can't be reached.
            MXLog.error("Failed downloading the shared image pack: \(error)")
            return cachedContent
        }
    }
    
    /// The default `DataLoader`, failing on any non-successful HTTP status.
    nonisolated static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw DownloadError.unexpectedResponse
        }
        return data
    }
}
