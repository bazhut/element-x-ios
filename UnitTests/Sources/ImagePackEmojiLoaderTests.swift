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
struct ImagePackEmojiLoaderTests {
    @Test("The user's image pack is loaded as a named category of custom emojis")
    func loadUserPack() async throws {
        let clientProxy = makeClientProxy(accountData: ["im.ponies.user_emotes": """
        {
            "pack": { "display_name": "Party" },
            "images": {
                "parrot": { "url": "mxc://example.com/parrot", "body": "Party parrot" },
                "blob": { "url": "mxc://example.com/blob" }
            }
        }
        """])
        
        let categories = await ImagePackEmojiLoader(clientProxy: clientProxy).load()
        
        let category = try #require(categories.first)
        #expect(categories.count == 1)
        #expect(category.id == EmojiCategory.customEmojiCategoryIdentifierPrefix + "im.ponies.user_emotes")
        #expect(category.name == "Party")
        #expect(category.emojis.map(\.label) == ["parrot", "blob"])
        #expect(category.emojis.map(\.key) == ["mxc://example.com/parrot", "mxc://example.com/blob"])
        #expect(category.emojis.first?.keywords == ["Party parrot"])
    }
    
    @Test("The emojis keep the order of the pack, whatever the content of their values")
    func keepPackOrder() async throws {
        let clientProxy = makeClientProxy(accountData: ["m.image_pack": #"""
        {
            "version": 1,
            "pack": { "display_name": "Braces { and \"quotes\" }", "usage": ["emoticon"] },
            "images": {
                "zebra": { "url": "mxc://example.com/zebra", "body": "Ends with } and ]" },
                "sm\u0069le": { "url": "mxc://example.com/smile", "info": { "w": 32, "tags": ["{", "["] } },
                "apple": { "url": "mxc://example.com/apple" }
            }
        }
        """#])
        
        let categories = await ImagePackEmojiLoader(clientProxy: clientProxy).load()
        
        let category = try #require(categories.first)
        #expect(category.name == #"Braces { and "quotes" }"#)
        #expect(category.emojis.map(\.label) == ["zebra", "smile", "apple"])
    }
    
    @Test("Stickers and malformed images are left out of the emojis")
    func filterImages() async throws {
        let clientProxy = makeClientProxy(accountData: ["m.image_pack": """
        {
            "pack": { "usage": ["sticker"] },
            "images": {
                "sticker": { "url": "mxc://example.com/sticker" },
                "emote": { "url": "mxc://example.com/emote", "usage": ["emoticon"] },
                "web": { "url": "https://example.com/web.png", "usage": ["emoticon"] },
                "broken": { "body": "No URL", "usage": ["emoticon"] }
            }
        }
        """])
        
        let categories = await ImagePackEmojiLoader(clientProxy: clientProxy).load()
        
        let category = try #require(categories.first)
        #expect(category.name == nil)
        #expect(category.emojis.map(\.label) == ["emote"])
    }
    
    @Test("An emoji found in both the stable and unstable packs is only listed once")
    func deduplicateEmojis() async {
        let pack = """
        { "images": { "parrot": { "url": "mxc://example.com/parrot" } } }
        """
        let clientProxy = makeClientProxy(accountData: ["m.image_pack": pack, "im.ponies.user_emotes": pack])
        
        let categories = await ImagePackEmojiLoader(clientProxy: clientProxy).load()
        
        #expect(categories.count == 1)
        #expect(categories.first?.emojis.count == 1)
    }
    
    @Test("The shared pack is listed after the user's packs, without the emojis they already have")
    func loadSharedPack() async throws {
        let clientProxy = makeClientProxy(accountData: ["im.ponies.user_emotes": #"{ "images": { "parrot": { "url": "mxc://example.com/parrot" } } }"#])
        let sharedPack = #"{ "pack": { "display_name": "Team" }, "images": { "parrot": { "url": "mxc://example.com/parrot" }, "ship_it": { "url": "mxc://example.com/ship" } } }"#
        
        let categories = await ImagePackEmojiLoader(clientProxy: clientProxy, sharedPackSource: SharedEmojiPackSourceStub(content: sharedPack)).load()
        
        #expect(categories.map(\.name) == [nil, "Team"])
        let sharedCategory = try #require(categories.last)
        #expect(sharedCategory.id == EmojiCategory.customEmojiCategoryIdentifierPrefix + "shared")
        #expect(sharedCategory.emojis.map(\.label) == ["ship_it"])
    }
    
    @Test("No categories are loaded when the user has no image packs")
    func loadWithoutPacks() async {
        let categories = await ImagePackEmojiLoader(clientProxy: makeClientProxy(accountData: [:])).load()
        #expect(categories.isEmpty)
    }
    
    // MARK: - Helpers
    
    private func makeClientProxy(accountData: [String: String]) -> ClientProxyMock {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.accountDataEventTypeClosure = { eventType in
            .success(accountData[eventType])
        }
        return clientProxy
    }
}

private struct SharedEmojiPackSourceStub: SharedEmojiPackSourceProtocol {
    let content: String?
    
    func fetch() async -> String? {
        content
    }
}
