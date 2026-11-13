//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing

@MainActor
struct EmojiPickerScreenViewModelTests {
    var emojiPickerStream: AsyncStream<String>!
    
    var viewModel: EmojiPickerScreenViewModel!
    var context: EmojiPickerScreenViewModel.Context {
        viewModel.context
    }
    
    @Test("Selecting an emoji yields it and dismisses the picker")
    mutating func selectEmoji() async throws {
        // Given a freshly presented emoji picker.
        setupViewModel()
        let reaction = "👋"
        
        // When the user taps an emoji.
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.send(viewAction: .emojiTapped(emoji: .init(id: "wave", value: reaction)))
        
        // Then the screen should dismiss and yield the emoji before finishing the stream.
        try await deferred.fulfill()
        var iterator = emojiPickerStream.makeAsyncIterator()
        #expect(await iterator.next() == reaction)
        #expect(await iterator.next() == nil)
    }
    
    @Test("Stopping the picker finishes the stream without an emoji")
    mutating func stopFinishesTheStream() async {
        // Given a freshly presented emoji picker.
        setupViewModel()
        
        // When it is stopped without a selection (e.g. the picker is dismissed).
        viewModel.stop()
        
        // Then the stream should finish without yielding an emoji.
        var iterator = emojiPickerStream.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }
    
    @Test("Custom emojis are offered for reactions but not for a user status",
          arguments: [(EmojiPickerScreenMode.reaction, true), (.userStatus, false)])
    mutating func customEmojis(mode: EmojiPickerScreenMode, isOffered: Bool) async throws {
        // Given a user with a custom emoji pack.
        let clientProxy = ClientProxyMock(.init())
        clientProxy.accountDataEventTypeClosure = { eventType in
            eventType == "im.ponies.user_emotes" ? .success(#"{ "images": { "parrot": { "url": "mxc://example.com/parrot" } } }"#) : .success(nil)
        }
        let emojiProvider = EmojiProvider(customEmojiLoader: ImagePackEmojiLoader(clientProxy: clientProxy), userSettings: .mock())
        
        // When the picker loads its emojis.
        setupViewModel(mode: mode, emojiProvider: emojiProvider)
        let deferred = deferFulfillment(context.observe(\.viewState.categories)) { !$0.isEmpty }
        try await deferred.fulfill()
        
        // Then the custom emoji is only offered when it can be used.
        let customEmoji = context.viewState.categories.flatMap(\.emojis).first { $0.imageURL != nil }
        #expect((customEmoji?.value == "mxc://example.com/parrot") == isOffered)
        #expect(customEmoji?.accessibilityName == (isOffered ? "parrot" : nil))
    }
    
    // MARK: - Helpers
    
    private mutating func setupViewModel(mode: EmojiPickerScreenMode = .reaction,
                                         selectedEmojis: Set<String> = [],
                                         emojiProvider: EmojiProviderProtocol = EmojiProvider(userSettings: .mock())) {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        emojiPickerStream = stream
        
        viewModel = EmojiPickerScreenViewModel(mode: mode,
                                               selectedEmojis: selectedEmojis,
                                               emojiProvider: emojiProvider,
                                               continuation: continuation)
    }
}
