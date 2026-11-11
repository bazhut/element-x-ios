//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

@MainActor
struct SharedEmojiPackSourceTests {
    private let packURL: URL = "https://example.com/emoji-pack.json"
    private let pack = #"{ "images": { "parrot": { "url": "mxc://example.com/parrot" } } }"#
    
    @Test("Nothing is downloaded when no shared pack is configured")
    func fetchWithoutURL() async {
        var downloadCount = 0
        let source = SharedEmojiPackSource(url: nil, dataLoader: { _ in
            downloadCount += 1
            return Data()
        })
        
        #expect(await source.fetch() == nil)
        #expect(downloadCount == 0)
    }
    
    @Test("The pack is downloaded once and then served from the cache")
    func fetchFromCache() async {
        var downloadCount = 0
        var date = Date(timeIntervalSince1970: 0)
        let source = SharedEmojiPackSource(url: packURL,
                                           dataLoader: { _ in
                                               downloadCount += 1
                                               return Data(pack.utf8)
                                           },
                                           now: { date })
        
        #expect(await source.fetch() == pack)
        date += 9 * 60
        #expect(await source.fetch() == pack)
        #expect(downloadCount == 1)
    }
    
    @Test("The pack is downloaded again once the cache expired, keeping the last one if the server fails")
    func fetchAfterExpiry() async {
        var downloadCount = 0
        var date = Date(timeIntervalSince1970: 0)
        let source = SharedEmojiPackSource(url: packURL,
                                           dataLoader: { _ in
                                               downloadCount += 1
                                               guard downloadCount == 1 else { throw SharedEmojiPackSource.DownloadError.unexpectedResponse }
                                               return Data(pack.utf8)
                                           },
                                           now: { date })
        
        #expect(await source.fetch() == pack)
        date += 11 * 60
        #expect(await source.fetch() == pack)
        #expect(downloadCount == 2)
    }
    
    @Test("Nothing is returned when the pack can't be downloaded")
    func fetchFailure() async {
        let source = SharedEmojiPackSource(url: packURL, dataLoader: { _ in
            throw SharedEmojiPackSource.DownloadError.unexpectedResponse
        })
        #expect(await source.fetch() == nil)
    }
}
