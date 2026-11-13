//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing
import UIKit

struct EmojiProviderTests {
    @Test("The categories are loaded from the loader") @MainActor
    func categoriesLoadedFromLoader() async {
        let item = EmojiItem(label: "test", unicode: "test", keywords: ["1", "2"], shortcodes: ["1", "2"])
        let category = EmojiCategory(id: "test", emojis: [item])
        
        let emojiLoaderMock = EmojiLoaderMock()
        emojiLoaderMock.categories = [category]
        
        let emojiProvider = EmojiProvider(loader: emojiLoaderMock, userSettings: .mock())
        
        let categories = await emojiProvider.categories()
        #expect(emojiLoaderMock.categories == categories)
    }
    
    @Test("An empty search returns every category") @MainActor
    func emptySearchReturnsAllCategories() async {
        let item = EmojiItem(label: "test", unicode: "test", keywords: ["1", "2"], shortcodes: ["1", "2"])
        let category = EmojiCategory(id: "test", emojis: [item])
        
        let emojiLoaderMock = EmojiLoaderMock()
        emojiLoaderMock.categories = [category]
        
        let emojiProvider = EmojiProvider(loader: emojiLoaderMock, userSettings: .mock())
        
        let categories = await emojiProvider.categories(searchString: "")
        #expect(emojiLoaderMock.categories == categories)
    }
    
    @Test("The built-in emojis are cached after the first load") @MainActor
    func cachedEmojis() async {
        let item = EmojiItem(label: "test", unicode: "test", keywords: ["1", "2"], shortcodes: ["1", "2"])
        let item2 = EmojiItem(label: "test2", unicode: "test2", keywords: ["3", "4"], shortcodes: ["3", "4"])
        let categoriesForFirstLoad = [EmojiCategory(id: "test",
                                                    emojis: [item])]
        let categoriesForSecondLoad = [EmojiCategory(id: "test2",
                                                     emojis: [item2])]
        
        let emojiLoaderMock = EmojiLoaderMock()
        emojiLoaderMock.categories = categoriesForFirstLoad
        
        let emojiProvider = EmojiProvider(loader: emojiLoaderMock, userSettings: .mock())
        
        _ = await emojiProvider.categories()
        emojiLoaderMock.categories = categoriesForSecondLoad
        
        let categories = await emojiProvider.categories()
        #expect(categories == categoriesForFirstLoad)
    }
    
    @Test("A search only returns the categories containing a match") @MainActor
    func searchFiltersCategories() async {
        let searchString = "smile"
        var categories = [EmojiCategory]()
        let item0WithSearchString = EmojiItem(label: "emoji0", unicode: "\(searchString)_123", keywords: ["key1", "key1"], shortcodes: ["key1", "key1"])
        let item1WithSearchString = EmojiItem(label: searchString, unicode: "emoji1", keywords: ["key1", "key1"], shortcodes: ["key1", "key1"])
        let item2WithSearchString = EmojiItem(label: "emoji_2", unicode: "emoji_2", keywords: ["key1", "\(searchString)_123"], shortcodes: ["key1", "key2"])
        let item3WithSearchString = EmojiItem(label: "emoji_2", unicode: "emoji_2", keywords: ["key1", "key1"], shortcodes: ["key1", "\(searchString)_123"])
        let item4WithoutSearchString = EmojiItem(label: "emoji_3", unicode: "emoji_3", keywords: ["key1", "key1"], shortcodes: ["key1", "key1"])
        let item5WithSearchString = EmojiItem(label: "emoji0", unicode: "\(searchString)_123", keywords: ["key1", "key1"], shortcodes: ["key1", "key1"])
        categories.append(EmojiCategory(id: "test",
                                        emojis: [item0WithSearchString,
                                                 item1WithSearchString,
                                                 item2WithSearchString,
                                                 item3WithSearchString,
                                                 item4WithoutSearchString]))
        categories.append(EmojiCategory(id: "test",
                                        emojis: [item5WithSearchString]))
        
        let emojiLoaderMock = EmojiLoaderMock()
        emojiLoaderMock.categories = categories
        
        let emojiProvider = EmojiProvider(loader: emojiLoaderMock, userSettings: .mock())
        
        _ = await emojiProvider.categories()
        let result = await emojiProvider.categories(searchString: searchString)
        #expect(result.count == 2)
        #expect(result.first?.emojis.count == 4)
    }
    
    @Test("Custom emojis are listed after the frequently used ones and before the built-in categories") @MainActor
    func providerIncludesCustomEmojis() async {
        let smile = EmojiItem(label: "smile", unicode: "😄", keywords: [], shortcodes: [])
        let parrot = EmojiItem(label: "parrot", unicode: ":parrot:", keywords: [], shortcodes: ["parrot"], imageURL: URL(string: "mxc://example.com/parrot"))
        let emojiProvider = EmojiProvider(loader: EmojiLoaderMock(categories: [EmojiCategory(id: "people", emojis: [smile])]),
                                          customEmojiLoader: EmojiLoaderMock(categories: [EmojiCategory(id: "custom", emojis: [parrot])]),
                                          userSettings: .mock())
        emojiProvider.markEmojiAsFrequentlyUsed("mxc://example.com/parrot")
        
        let categories = await emojiProvider.categories(searchString: nil)
        
        #expect(categories.map(\.id) == [EmojiCategory.frequentlyUsedCategoryIdentifier, "custom", "people"])
        #expect(categories.first?.emojis.first?.key == "mxc://example.com/parrot")
        
        let searchResults = await emojiProvider.categories(searchString: "parr")
        #expect(searchResults.map(\.id) == [EmojiCategory.frequentlyUsedCategoryIdentifier, "custom"])
    }
}

private class EmojiLoaderMock: EmojiLoaderProtocol {
    var categories = [ElementX.EmojiCategory]()
    
    init(categories: [ElementX.EmojiCategory] = []) {
        self.categories = categories
    }
    
    func load() async -> [ElementX.EmojiCategory] {
        categories
    }
}
