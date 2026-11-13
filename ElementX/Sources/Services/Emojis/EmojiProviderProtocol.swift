//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct EmojiItem: Equatable, Identifiable {
    var id: String {
        label
    }
    
    let label: String
    let unicode: String
    let keywords: [String]
    let shortcodes: [String]
    /// The image of a custom emoji, sent as its reaction key (MSC4027).
    var imageURL: URL?
    
    /// The reaction key to send for this emoji.
    var key: String {
        imageURL?.absoluteString ?? unicode
    }
}

struct EmojiCategory: Equatable, Identifiable {
    static let frequentlyUsedCategoryIdentifier = "io.element.elementx.frequently_used"
    static let customEmojiCategoryIdentifierPrefix = "io.element.elementx.custom_emoji."
    
    let id: String
    let emojis: [EmojiItem]
    /// The display name of a custom emoji pack. Built-in categories are named from their `id`.
    var name: String?
}

enum EmojiProviderState {
    case notLoaded
    case inProgress(Task<[EmojiCategory], Never>)
    case loaded([EmojiCategory])
}

protocol EmojiProviderProtocol {
    func categories(searchString: String?) async -> [EmojiCategory]
    
    func frequentlyUsedSystemEmojis() -> [String]
    func markEmojiAsFrequentlyUsed(_ emoji: String)
}
