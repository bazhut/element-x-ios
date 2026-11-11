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
    /// The shortcodes in the order of the JSON, as decoding `images` into a dictionary loses it.
    private(set) var shortcodeOrder: [String] = []
    
    /// The images usable as emojis, in the order of the pack.
    var emoticons: [Emoticon] {
        let positions = Dictionary(shortcodeOrder.enumerated().map { ($1, $0) }) { first, _ in first }
        return images
            .filter { _, image in
                // An image without a usage inherits the pack's, and a pack without one allows every usage.
                (image.usage ?? pack?.usage)?.contains("emoticon") ?? true
            }
            .sorted { (positions[$0.key] ?? .max, $0.key) < (positions[$1.key] ?? .max, $1.key) }
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
        shortcodeOrder = JSONObjectKeyScanner.keys(ofObjectNamed: CodingKeys.images.rawValue, in: data) ?? []
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pack = try container.decodeIfPresent(Pack.self, forKey: .pack)
        images = try (container.decodeIfPresent([String: LossyImage].self, forKey: .images) ?? [:]).compactMapValues(\.image)
    }
}

/// Reads the keys of an object nested in a JSON object in the order of the document, which `JSONDecoder` doesn't preserve.
private nonisolated struct JSONObjectKeyScanner {
    private let bytes: [UInt8]
    private var index = 0
    
    /// The keys of the object stored under `name` in the root object, or `nil` if there isn't one.
    static func keys(ofObjectNamed name: String, in data: Data) -> [String]? {
        var scanner = JSONObjectKeyScanner(bytes: Array(data))
        return scanner.keysOfMember(named: name)
    }
    
    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }
    
    private mutating func keysOfMember(named name: String) -> [String]? {
        guard consume(UInt8(ascii: "{")) else { return nil }
        while let key = nextKey() {
            if key == name {
                return objectKeys()
            }
            guard skipValue() else { return nil }
        }
        return nil
    }
    
    private mutating func objectKeys() -> [String]? {
        guard consume(UInt8(ascii: "{")) else { return nil }
        var keys = [String]()
        while let key = nextKey() {
            keys.append(key)
            guard skipValue() else { return nil }
        }
        return keys
    }
    
    /// Reads the key of the next member and its colon, or returns `nil` at the end of the object.
    private mutating func nextKey() -> String? {
        _ = consume(UInt8(ascii: ","))
        skipWhitespace()
        guard index < bytes.count, bytes[index] == UInt8(ascii: "\""), let key = readString() else { return nil }
        return consume(UInt8(ascii: ":")) ? key : nil
    }
    
    private mutating func readString() -> String? {
        let start = index
        guard skipString() else { return nil }
        // Decoding the quoted string unescapes it.
        return try? JSONDecoder().decode(String.self, from: Data(bytes[start..<index]))
    }
    
    /// Skips a string, starting at its opening quote.
    private mutating func skipString() -> Bool {
        index += 1
        while index < bytes.count {
            switch bytes[index] {
            case UInt8(ascii: "\\"):
                index += 2
            case UInt8(ascii: "\""):
                index += 1
                return true
            default:
                index += 1
            }
        }
        return false
    }
    
    private mutating func skipValue() -> Bool {
        skipWhitespace()
        guard index < bytes.count else { return false }
        
        switch bytes[index] {
        case UInt8(ascii: "\""):
            return skipString()
        case UInt8(ascii: "{"), UInt8(ascii: "["):
            var depth = 0
            while index < bytes.count {
                switch bytes[index] {
                case UInt8(ascii: "\""):
                    guard skipString() else { return false }
                    continue
                case UInt8(ascii: "{"), UInt8(ascii: "["):
                    depth += 1
                case UInt8(ascii: "}"), UInt8(ascii: "]"):
                    depth -= 1
                default:
                    break
                }
                index += 1
                if depth == 0 {
                    return true
                }
            }
            return false
        default:
            // A number, a boolean or null, which end at the next separator.
            while index < bytes.count, ![UInt8(ascii: ","), UInt8(ascii: "}"), UInt8(ascii: "]")].contains(bytes[index]) {
                index += 1
            }
            return true
        }
    }
    
    private mutating func consume(_ byte: UInt8) -> Bool {
        skipWhitespace()
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }
    
    private mutating func skipWhitespace() {
        while index < bytes.count, [UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: "\r"), UInt8(ascii: "\t")].contains(bytes[index]) {
            index += 1
        }
    }
}
