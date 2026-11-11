//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

struct TimelineItemMenuActionProviderTests {
    @Test("A live location share can't be forwarded")
    func liveLocationShareIsNotForwardable() throws {
        let item = makeLiveLocationItem(isLive: true)
        let actions = try #require(makeActions(for: item))
        
        let hasForward = actions.actions.contains(where: \.isForward)
        #expect(!hasForward)
    }
    
    @Test("An ended live location share can't be forwarded")
    func endedLiveLocationShareIsNotForwardable() throws {
        let item = makeLiveLocationItem(isLive: false)
        let actions = try #require(makeActions(for: item))
        
        let hasForward = actions.actions.contains(where: \.isForward)
        #expect(!hasForward)
    }
    
    @Test("A poll can't be forwarded")
    func pollIsNotForwardable() throws {
        let item = PollRoomTimelineItem.mock(poll: .emptyDisclosed)
        let actions = try #require(makeActions(for: item))
        
        let hasForward = actions.actions.contains(where: \.isForward)
        #expect(!hasForward)
    }
    
    @Test("A text message can be forwarded")
    func textMessageIsForwardable() throws {
        let item = TextRoomTimelineItem(id: .randomEvent,
                                        timestamp: .mock,
                                        isOutgoing: false,
                                        isEditable: false,
                                        canBeRepliedTo: true,
                                        sender: .init(id: "@alice:matrix.org"),
                                        content: .init(body: "Hello"))
        let actions = try #require(makeActions(for: item))
        
        let hasForward = actions.actions.contains(where: \.isForward)
        #expect(hasForward)
    }
    
    @Test("A redacted message can't be forwarded")
    func redactedMessageIsNotForwardable() throws {
        let item = RedactedRoomTimelineItem(id: .randomEvent,
                                            body: "Message removed",
                                            timestamp: .mock,
                                            isOutgoing: false,
                                            isEditable: false,
                                            canBeRepliedTo: false,
                                            sender: .init(id: "@alice:matrix.org"))
        let actions = try #require(makeActions(for: item))
        
        let hasForward = actions.actions.contains(where: \.isForward)
        #expect(!hasForward)
    }
    
    @Test("A message that can't be decrypted can't be forwarded")
    func encryptedMessageIsNotForwardable() throws {
        let item = EncryptedRoomTimelineItem(id: .randomEvent,
                                             body: "",
                                             encryptionType: .unknown,
                                             timestamp: .mock,
                                             isOutgoing: false,
                                             isEditable: false,
                                             canBeRepliedTo: false,
                                             sender: .init(id: "@alice:matrix.org"))
        let actions = try #require(makeActions(for: item))
        
        let hasForward = actions.actions.contains(where: \.isForward)
        #expect(!hasForward)
    }
    
    @Test("A message that hasn't been sent yet can't be forwarded")
    func localEchoIsNotForwardable() throws {
        let item = makeTextItem(id: .event(uniqueID: .init("local"), eventOrTransactionID: .transactionID("txn")))
        let actions = try #require(makeActions(for: item))
        
        let hasForward = actions.actions.contains(where: \.isForward)
        #expect(!hasForward)
    }
    
    @Test("A frequently used custom emoji is offered as a quick reaction after the default ones")
    func customEmojiQuickReaction() throws {
        let emojiProvider = EmojiProvider(userSettings: .mock())
        emojiProvider.markEmojiAsFrequentlyUsed("mxc://example.com/parrot")
        
        let actions = try #require(makeActions(for: makeTextItem(), emojiProvider: emojiProvider))
        
        let customReaction = try #require(actions.reactions.last)
        #expect(customReaction.key == "mxc://example.com/parrot")
        #expect(customReaction.imageURL == URL(string: "mxc://example.com/parrot"))
        #expect(actions.reactions.dropLast().allSatisfy { $0.imageURL == nil })
    }
    
    // MARK: - Helpers
    
    private func makeTextItem(id: TimelineItemIdentifier = .randomEvent) -> TextRoomTimelineItem {
        .init(id: id,
              timestamp: .mock,
              isOutgoing: false,
              isEditable: false,
              canBeRepliedTo: true,
              sender: .init(id: "@alice:matrix.org"),
              content: .init(body: "Hello"))
    }
    
    private func makeLiveLocationItem(isLive: Bool) -> LiveLocationRoomTimelineItem {
        .init(id: .randomEvent,
              timestamp: .mock,
              isOutgoing: false,
              isEditable: false,
              canBeRepliedTo: true,
              sender: .init(id: "@alice:matrix.org"),
              content: .init(isLive: isLive, timeoutDate: .mock, lastGeoURI: nil))
    }
    
    private func makeActions(for item: RoomTimelineItemProtocol,
                             timelineKind: TimelineKind = .live,
                             emojiProvider: EmojiProviderProtocol = EmojiProvider(userSettings: .mock())) -> TimelineItemMenuActions? {
        TimelineItemMenuActionProvider(timelineItem: item,
                                       canCurrentUserSendMessage: true,
                                       canCurrentUserRedactSelf: true,
                                       canCurrentUserRedactOthers: false,
                                       canCurrentUserPin: true,
                                       pinnedEventIDs: [],
                                       isViewSourceEnabled: true,
                                       areThreadsEnabled: true,
                                       timelineKind: timelineKind,
                                       emojiProvider: emojiProvider)
            .makeActions()
    }
}

private extension TimelineItemMenuAction {
    var isForward: Bool {
        if case .forward = self {
            return true
        }
        return false
    }
}
