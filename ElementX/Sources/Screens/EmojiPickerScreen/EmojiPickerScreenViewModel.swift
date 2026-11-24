//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias EmojiPickerScreenViewModelType = StateStoreViewModelV2<EmojiPickerScreenViewState, EmojiPickerScreenViewAction>

class EmojiPickerScreenViewModel: EmojiPickerScreenViewModelType, EmojiPickerScreenViewModelProtocol {
    private let emojiProvider: EmojiProviderProtocol
    private let continuation: EmojiPickerScreenContinuation
    
    private var actionsSubject: PassthroughSubject<EmojiPickerScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<EmojiPickerScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(mode: EmojiPickerScreenMode = .reaction,
         selectedEmojis: Set<String>,
         emojiProvider: EmojiProviderProtocol,
         mediaProvider: MediaProviderProtocol? = nil,
         continuation: EmojiPickerScreenContinuation) {
        let initialViewState = EmojiPickerScreenViewState(mode: mode, categories: [], selectedEmojis: selectedEmojis)
        self.emojiProvider = emojiProvider
        self.continuation = continuation
        super.init(initialViewState: initialViewState, mediaProvider: mediaProvider)
        loadEmojis()
    }
    
    // MARK: - Public
    
    func stop() {
        continuation.finish() // Ensure the continuation always finishes even without a selection.
    }
    
    override func process(viewAction: EmojiPickerScreenViewAction) {
        switch viewAction {
        case let .search(searchString: searchString):
            Task {
                let categories = await emojiProvider.categories(searchString: searchString)
                state.categories = convert(emojiCategories: categories)
            }
        case let .emojiTapped(emoji: emoji):
            selectEmoji(emoji)
        case .dismiss:
            actionsSubject.send(.dismiss)
        }
    }
    
    // MARK: - Private
    
    private func loadEmojis() {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let categories = await self.emojiProvider.categories(searchString: nil)
            self.state.categories = convert(emojiCategories: categories)
        }
    }
    
    private func convert(emojiCategories: [EmojiCategory]) -> [EmojiPickerEmojiCategoryViewData] {
        emojiCategories.compactMap { emojiCategory in
            let emojisViewData: [EmojiPickerEmojiViewData] = emojiCategory.emojis.compactMap { emojiItem in
                // A status is plain text, so it can't hold a custom emoji.
                if state.mode == .userStatus, emojiItem.imageURL != nil {
                    return nil
                }
                
                return EmojiPickerEmojiViewData(id: "\(emojiCategory.id)-\(emojiItem.id)",
                                                value: emojiItem.key,
                                                imageURL: emojiItem.imageURL,
                                                label: emojiItem.imageURL == nil ? nil : emojiItem.label)
            }
            
            guard !emojisViewData.isEmpty else { return nil }
            
            return EmojiPickerEmojiCategoryViewData(id: emojiCategory.id, emojis: emojisViewData, packName: emojiCategory.name)
        }
    }
    
    private func selectEmoji(_ emoji: EmojiPickerEmojiViewData) {
        emojiProvider.markEmojiAsFrequentlyUsed(emoji.value)
        
        continuation.yield(emoji.value)
        continuation.finish()
        
        actionsSubject.send(.dismiss)
    }
}
