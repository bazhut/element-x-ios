//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// A square image of a custom emoji, sized to sit alongside unicode emojis.
struct CustomEmojiImage: View {
    let url: URL
    let size: CGFloat
    let mediaProvider: MediaProviderProtocol?

    var body: some View {
        // Reaction keys carry no mimetype, so always hint `image/gif` to take LoadableImage's animated path.
        // Kingfisher sniffs the actual format, so static images still render (full size, no thumbnail).
        if let mediaSource = try? MediaSourceProxy(url: url, mimeType: "image/gif") {
            LoadableImage(mediaSource: mediaSource,
                          size: CGSize(width: size, height: size),
                          mediaProvider: mediaProvider,
                          transformer: { $0.scaledToFit() },
                          placeholder: { Color.clear })
                .frame(width: size, height: size)
        }
    }
}
