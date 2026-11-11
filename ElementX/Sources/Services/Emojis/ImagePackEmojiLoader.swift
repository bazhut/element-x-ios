//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Loads the custom emojis from MSC2545 image packs: the user's packs in their account data, then the pack shared with every user.
///
/// An emoji found in several packs is only kept in the first one, as its URL is used as the reaction key.
struct ImagePackEmojiLoader: EmojiLoaderProtocol {
    // Most clients still write the unstable type, so read both.
    private static let eventTypes = ["m.image_pack", "im.ponies.user_emotes"]
    private static let sharedPackIdentifier = "shared"
    
    let clientProxy: ClientProxyProtocol
    var sharedPackSource: SharedEmojiPackSourceProtocol?
    
    func load() async -> [EmojiCategory] {
        var packs = [(id: String, json: String)]()
        for eventType in Self.eventTypes {
            if case let .success(json?) = await clientProxy.accountData(eventType: eventType) {
                packs.append((eventType, json))
            }
        }
        if let json = await sharedPackSource?.fetch() {
            packs.append((Self.sharedPackIdentifier, json))
        }
        
        var loadedKeys = Set<String>()
        return packs.compactMap { id, json in
            guard let pack = ImagePackContent(json: json) else { return nil }
            
            let emojis = pack.emoticons
                .map { emoticon in
                    EmojiItem(label: emoticon.shortcode,
                              unicode: ":\(emoticon.shortcode):",
                              keywords: emoticon.body.map { [$0] } ?? [],
                              shortcodes: [emoticon.shortcode],
                              imageURL: emoticon.url)
                }
                .filter { loadedKeys.insert($0.key).inserted }
            guard !emojis.isEmpty else { return nil }
            
            return EmojiCategory(id: EmojiCategory.customEmojiCategoryIdentifierPrefix + id,
                                 emojis: emojis,
                                 name: pack.pack?.displayName)
        }
    }
}

/// The content of an MSC2545 image pack event.
nonisolated struct ImagePackContent: Decodable {
    nonisolated struct Pack: Decodable {
        let displayName: String?
        let usage: [String]?
        
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case usage
        }
    }
    
    nonisolated struct Image: Decodable {
        let url: String
        let body: String?
        let usage: [String]?
    }
    
    /// An image that can be used as an emoji.
    nonisolated struct Emoticon {
        let shortcode: String
        let url: URL
        let body: String?
    }
    
    /// Decodes a single image, leaving it `nil` when malformed so one bad entry doesn't drop the whole pack.
    private nonisolated struct LossyImage: Decodable {
        let image: Image?
        
        init(from decoder: Decoder) throws {
            image = try? Image(from: decoder)
        }
    }
    
    let pack: Pack?
    let images: [String: Image]
    
    /// The images usable as emojis, sorted by shortcode.
    var emoticons: [Emoticon] {
        images
            .filter { _, image in
                // An image without a usage inherits the pack's, and a pack without one allows every usage.
                (image.usage ?? pack?.usage)?.contains("emoticon") ?? true
            }
            .sorted { $0.key < $1.key }
            .compactMap { shortcode, image in
                guard image.url.hasPrefix("mxc://"), let url = URL(string: image.url) else { return nil }
                return Emoticon(shortcode: shortcode, url: url, body: image.body)
            }
    }
    
    enum CodingKeys: String, CodingKey {
        case pack
        case images
    }
    
    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let content = try? JSONDecoder().decode(ImagePackContent.self, from: data) else {
            MXLog.error("Failed decoding image pack")
            return nil
        }
        self = content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pack = try container.decodeIfPresent(Pack.self, forKey: .pack)
        images = try (container.decodeIfPresent([String: LossyImage].self, forKey: .images) ?? [:]).compactMapValues(\.image)
    }
}
