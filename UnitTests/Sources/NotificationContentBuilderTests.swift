//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Dynamic
@testable import ElementX
import MatrixRustSDK
import MatrixRustSDKMocks
import Testing
import UserNotifications

nonisolated struct NotificationContentBuilderTests {
    var notificationContentBuilder: NotificationContentBuilder
    var mediaProvider: MediaProviderMock
    var notificationContent: UNMutableNotificationContent
    
    init() async {
        notificationContent = .init()
        let stringBuilder = RoomMessageEventStringBuilder(attributedStringBuilder: AttributedStringBuilder(mentionBuilder: PlainMentionBuilder(), rendersEmoticonsAsImages: false),
                                                          style: .plain)
        mediaProvider = MediaProviderMock(.init())
        notificationContentBuilder = await NotificationContentBuilder(messageEventStringBuilder: stringBuilder,
                                                                      userSession: NSEUserSessionMock(.init()))
    }
    
    @Test("A DM message notification shows the sender")
    mutating func dmMessageNotification() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!test:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "Alice",
                                                               roomJoinedMembers: 2,
                                                               isRoomDirect: true,
                                                               isRoomPrivate: true,
                                                               isNoisy: true))
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        // Checking if nil without using asObject always fails
        #expect(communicationContext.displayName.asObject == nil)
        #expect(communicationContext.sender.displayName == "Alice")
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID == nil)
        #expect(notificationContent.sound != nil)
        // Remember we remove the @ due to an iOS bug
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!test:matrix.org")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A DM message notification with a mention marks the mention")
    mutating func dmMessageNotificationWithMention() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!test:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "Alice",
                                                               roomJoinedMembers: 2,
                                                               isRoomDirect: true,
                                                               isRoomPrivate: true,
                                                               isNoisy: true,
                                                               hasMention: true))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        // Checking if nil without using asObject always fails
        #expect(communicationContext.displayName.asObject == nil)
        #expect(communicationContext.sender.displayName == L10n.notificationSenderMentionReply("Alice"))
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID == nil)
        #expect(notificationContent.sound != nil)
        // Remember we remove the @ due to an iOS bug
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!test:matrix.org")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A threaded DM message notification is grouped by thread")
    mutating func dmMessageNotificationWithThread() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!test:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "Alice",
                                                               roomJoinedMembers: 2,
                                                               isRoomDirect: true,
                                                               isRoomPrivate: true,
                                                               isNoisy: true,
                                                               hasMention: false,
                                                               threadRootEventID: "thread"))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        #expect(communicationContext.displayName == L10n.commonThread)
        #expect(communicationContext.sender.displayName == "Alice")
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID != nil)
        #expect(notificationContent.sound != nil)
        // Remember we remove the @ due to an iOS bug
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!test:matrix.orgthread")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A threaded DM message notification with a mention is grouped by thread")
    mutating func dmMessageNotificationWithThreadAndMention() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!test:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "Alice",
                                                               roomJoinedMembers: 2,
                                                               isRoomDirect: true,
                                                               isRoomPrivate: true,
                                                               isNoisy: true,
                                                               hasMention: true,
                                                               threadRootEventID: "thread"))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        #expect(communicationContext.displayName == L10n.commonThread)
        #expect(communicationContext.sender.displayName == L10n.notificationSenderMentionReply("Alice"))
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID != nil)
        #expect(notificationContent.sound != nil)
        // Remember we remove the @ due to an iOS bug
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!test:matrix.orgthread")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A room message notification shows the sender and the room")
    mutating func roomMessageNotification() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!testroom:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "General",
                                                               roomJoinedMembers: 5,
                                                               isRoomDirect: false,
                                                               isRoomPrivate: false,
                                                               isNoisy: false))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        
        #expect(communicationContext.displayName == "General")
        #expect(communicationContext.sender.displayName == "Alice")
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID == nil)
        #expect(notificationContent.sound == nil)
        // Remember we remove the @ due to an iOS bug
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!testroom:matrix.org")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A room message notification with a mention marks the mention")
    mutating func roomMessageNotificationWithMention() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!testroom:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "General",
                                                               roomJoinedMembers: 5,
                                                               isRoomDirect: false,
                                                               isRoomPrivate: false,
                                                               isNoisy: true,
                                                               hasMention: true))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        #expect(communicationContext.displayName == "General")
        #expect(communicationContext.sender.displayName == L10n.notificationSenderMentionReply("Alice"))
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID == nil)
        #expect(notificationContent.sound != nil)
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!testroom:matrix.org")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A threaded room message notification names the thread")
    mutating func roomMessageNotificationWithThread() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!testroom:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "General",
                                                               roomJoinedMembers: 5,
                                                               isRoomDirect: false,
                                                               isRoomPrivate: false,
                                                               isNoisy: false,
                                                               threadRootEventID: "thread123"))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        #expect(communicationContext.displayName == L10n.notificationThreadInRoom("General"))
        #expect(communicationContext.sender.displayName == "Alice")
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID != nil)
        #expect(notificationContent.sound == nil)
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!testroom:matrix.orgthread123")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A live location notification uses the live location text")
    mutating func liveLocationStartNotification() async {
        let event = TimelineEventSDKMock()
        event.eventIdReturnValue = UUID().uuidString
        event.timestampReturnValue = 0
        event.contentReturnValue = .state(content: .beaconInfo)
        
        let notificationItem = NotificationItemProxyMock(.init(event: .timeline(event: event),
                                                               roomID: "!test:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "Alice",
                                                               roomJoinedMembers: 2,
                                                               isRoomDirect: true,
                                                               isRoomPrivate: true,
                                                               isNoisy: true))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        #expect(communicationContext.sender.displayName == "Alice")
        #expect(notificationContent.body == L10n.notificationLiveLocationStartedBody)
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.sound != nil)
    }
    
    @Test("Any other state event uses the generic notification text")
    mutating func otherStateEventNotification() async {
        let event = TimelineEventSDKMock()
        event.eventIdReturnValue = UUID().uuidString
        event.timestampReturnValue = 0
        event.contentReturnValue = .state(content: .roomName)
        
        let notificationItem = NotificationItemProxyMock(.init(event: .timeline(event: event),
                                                               roomID: "!test:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "Alice",
                                                               roomJoinedMembers: 2,
                                                               isRoomDirect: true,
                                                               isRoomPrivate: true,
                                                               isNoisy: true))
        
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        
        #expect(notificationContent.body == L10n.notification)
    }
    
    @Test("A threaded room message notification with a mention names the thread and marks the mention")
    mutating func roomMessageNotificationWithThreadAndMention() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!testroom:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "General",
                                                               roomJoinedMembers: 5,
                                                               isRoomDirect: false,
                                                               isRoomPrivate: false,
                                                               isNoisy: true,
                                                               hasMention: true,
                                                               threadRootEventID: "thread123"))
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        let communicationContext = Dynamic(notificationContent, memberName: "communicationContext")
        #expect(communicationContext.displayName == L10n.notificationThreadInRoom("General"))
        #expect(communicationContext.sender.displayName == L10n.notificationSenderMentionReply("Alice"))
        #expect(notificationContent.body == "Hello world!")
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.message)
        #expect(notificationContent.threadRootEventID != nil)
        #expect(notificationContent.sound != nil)
        #expect(notificationContent.threadIdentifier == "bob:matrix.org!testroom:matrix.orgthread123")
        #expect(notificationContent.attachments == [])
    }
    
    @Test("A call that CallKit can't present rings with the notification until it expires")
    mutating func ringingCallNotification() async {
        let notificationItem = NotificationItemProxyMock(.init(roomID: "!testroom:matrix.org",
                                                               receiverID: "@bob:matrix.org",
                                                               senderDisplayName: "Alice",
                                                               roomDisplayName: "General",
                                                               roomJoinedMembers: 5,
                                                               isRoomDirect: false,
                                                               isRoomPrivate: false,
                                                               isNoisy: true))
        let expirationDate = Date.now.addingTimeInterval(30)
        await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                 notificationItem: notificationItem,
                                                 mediaProvider: mediaProvider)
        notificationContentBuilder.processRingingCall(notificationContent: &notificationContent,
                                                      isVoiceCall: true,
                                                      expirationDate: expirationDate)
        
        #expect(notificationContent.categoryIdentifier == NotificationConstants.Category.incomingCall)
        #expect(notificationContent.body == L10n.notificationIncomingAudioCall)
        #expect(notificationContent.sound == NotificationTone.ringtone.notificationSound)
        #expect(notificationContent.interruptionLevel == .timeSensitive)
        #expect(notificationContent.roomID == "!testroom:matrix.org")
        #expect(notificationContent.receiverID == "@bob:matrix.org")
        #expect(notificationContent.isVoiceCall)
        #expect(notificationContent.isRingingCall(at: .now))
        #expect(!notificationContent.isRingingCall(at: expirationDate.addingTimeInterval(1)))
    }
    
    @Test("A ringing video call uses the video call text")
    mutating func ringingVideoCallNotification() {
        notificationContentBuilder.processRingingCall(notificationContent: &notificationContent,
                                                      isVoiceCall: false,
                                                      expirationDate: .now.addingTimeInterval(30))
        
        #expect(notificationContent.body == L10n.notificationIncomingCall)
        #expect(!notificationContent.isVoiceCall)
    }
    
    @Test("A message notification never counts as a ringing call")
    mutating func messageNotificationIsNotRingingCall() {
        notificationContent.categoryIdentifier = NotificationConstants.Category.message
        notificationContent.callExpirationDate = .now.addingTimeInterval(30)
        
        #expect(!notificationContent.isRingingCall(at: .now))
    }
}
