//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import MatrixRustSDKMocks
import NotificationCenter
import Testing

@MainActor
final class NotificationManagerTests {
    var notificationManager: NotificationManager!
    private var notificationCenter: UserNotificationCenterMock!
    private let appSettings: AppSettings
    private var authorizationStatusWasGranted = false
    private var shouldDisplayInAppNotificationReturnValue = false
    private var handleInlineReplyDelegateCalled = false
    private var notificationTappedDelegateCalled = false
    private var registerForRemoteNotificationsDelegateCalled: (() -> Void)?
    private var unregisterForRemoteNotificationsDelegateCalled = false
    
    init() {
        appSettings = AppSettings.volatile()
        notificationCenter = UserNotificationCenterMock()
        notificationCenter.requestAuthorizationOptionsReturnValue = true
        notificationCenter.authorizationStatusReturnValue = .authorized
        notificationCenter.deliveredNotificationsReturnValue = []
        notificationCenter.notificationSettingsClosure = { await UNUserNotificationCenter.current().notificationSettings() }
        
        notificationManager = NotificationManager(notificationCenter: notificationCenter, appSettings: appSettings)
        notificationManager.start()
    }
    
    isolated deinit {
        notificationCenter = nil
        notificationManager = nil
    }
    
    // MARK: - Device token
    
    @Test("Registering hands the device token to every account")
    func registerDeviceToken() async {
        let alice = makeService("@alice:example.com")
        let bob = makeService("@bob:example.com")
        notificationManager.add(alice.service)
        notificationManager.add(bob.service)
        let deviceToken = Data("1234".utf8)
        
        await notificationManager.register(with: deviceToken)
        
        #expect(alice.service.registerDeviceTokenReceivedDeviceToken == deviceToken)
        #expect(bob.service.registerDeviceTokenReceivedDeviceToken == deviceToken)
    }
    
    @Test("An account added afterwards gets the saved device token")
    func addAccountAfterRegistering() async {
        let deviceToken = Data("1234".utf8)
        await notificationManager.register(with: deviceToken)
        let alice = makeService("@alice:example.com")
        
        await waitForConfirmation("The saved token should be registered", timeout: .seconds(10)) { confirm in
            alice.service.registerDeviceTokenClosure = { _ in confirm() }
            notificationManager.add(alice.service)
        }
        
        #expect(alice.service.registerDeviceTokenReceivedDeviceToken == deviceToken)
    }
    
    @Test("A replaced service registers again and the old one is ignored")
    func replaceService() async {
        let oldBadgeCountSubject = CurrentValueSubject<Int, Never>(3)
        let oldAlice = makeService("@alice:example.com")
        oldAlice.service.badgeCountPublisher = oldBadgeCountSubject.asCurrentValuePublisher()
        notificationManager.add(oldAlice.service)
        await notificationManager.register(with: Data("1234".utf8))
        let newAlice = makeService("@alice:example.com", badgeCount: 1)
        
        await waitForConfirmation("The new service should register", timeout: .seconds(10)) { confirm in
            newAlice.service.registerDeviceTokenClosure = { _ in confirm() }
            notificationManager.add(newAlice.service)
        }
        oldBadgeCountSubject.send(5)
        
        #expect(oldAlice.service.registerDeviceTokenCallsCount == 1)
        #expect(appSettings.lastKnownBadgeCount == 1)
    }
    
    @Test("The device token is forgotten once the last account is removed")
    func removeLastAccount() async throws {
        notificationManager.add(makeService("@alice:example.com").service)
        await notificationManager.register(with: Data("1234".utf8))
        notificationManager.remove(userID: "@alice:example.com")
        let bob = makeService("@bob:example.com")
        
        // The app unregisters from APNs when signing out of the last account, so the old token is dead.
        notificationManager.add(bob.service)
        try await Task.sleep(for: .milliseconds(500))
        
        #expect(!bob.service.registerDeviceTokenCalled)
    }
    
    // MARK: - Permission
    
    @Test("Adding an account registers when permission was given")
    func addAccountWithPermission() async {
        notificationManager.delegate = self
        
        await waitForConfirmation("registerForRemoteNotifications should be called", timeout: .seconds(10)) { confirm in
            registerForRemoteNotificationsDelegateCalled = { confirm() }
            notificationManager.add(makeService("@alice:example.com").service)
        }
        
        #expect(authorizationStatusWasGranted)
    }
    
    @Test("Adding an account registers even when its notifications are off")
    func addDisabledAccount() async {
        notificationManager.delegate = self
        
        // So that accounts turned off delete any pusher left on their homeserver.
        await waitForConfirmation("registerForRemoteNotifications should be called", timeout: .seconds(10)) { confirm in
            registerForRemoteNotificationsDelegateCalled = { confirm() }
            notificationManager.add(makeService("@alice:example.com", isEnabled: false).service)
        }
        
        #expect(authorizationStatusWasGranted)
    }
    
    @Test("Adding an account never asks for permission")
    func addAccountWithoutPermission() async throws {
        notificationCenter.authorizationStatusReturnValue = .notDetermined
        notificationManager.delegate = self
        
        notificationManager.add(makeService("@alice:example.com").service)
        try await Task.sleep(for: .seconds(1))
        
        #expect(!notificationCenter.requestAuthorizationOptionsCalled)
        #expect(!authorizationStatusWasGranted)
    }
    
    @Test("An account asking for permission requests authorization")
    func requestAuthorization() async {
        let alice = makeService("@alice:example.com")
        notificationManager.add(alice.service)
        
        await waitForConfirmation("requestAuthorization should be called", timeout: .seconds(10)) { confirm in
            notificationCenter.requestAuthorizationOptionsClosure = { _ in
                confirm()
                return true
            }
            alice.actions.send(.requestAuthorization)
        }
        
        #expect(notificationCenter.requestAuthorizationOptionsReceivedOptions == [.alert, .sound, .badge])
    }
    
    @Test("Granting permission registers for remote notifications")
    func grantPermission() async {
        notificationCenter.authorizationStatusReturnValue = .notDetermined
        notificationManager.delegate = self
        let alice = makeService("@alice:example.com")
        notificationManager.add(alice.service)
        
        await waitForConfirmation("registerForRemoteNotifications should be called", timeout: .seconds(10)) { confirm in
            registerForRemoteNotificationsDelegateCalled = { confirm() }
            alice.actions.send(.requestAuthorization)
        }
        
        #expect(notificationCenter.requestAuthorizationOptionsReceivedOptions == [.alert, .sound, .badge])
    }
    
    @Test("Asking for permission with every account off does nothing")
    func requestAuthorizationWithEveryAccountOff() async throws {
        let alice = makeService("@alice:example.com", isEnabled: false)
        notificationManager.add(alice.service)
        
        alice.actions.send(.requestAuthorization)
        try await Task.sleep(for: .seconds(1))
        
        #expect(!notificationCenter.requestAuthorizationOptionsCalled)
    }
    
    // MARK: - Badge
    
    @Test("The app badge sums every account")
    func appBadgeSum() {
        notificationManager.add(makeService("@alice:example.com", badgeCount: 3).service)
        notificationManager.add(makeService("@bob:example.com", badgeCount: 2).service)
        
        #expect(appSettings.lastKnownBadgeCount == 5)
    }
    
    @Test("The app badge follows an account's count")
    func appBadgeUpdates() {
        let badgeCountSubject = CurrentValueSubject<Int, Never>(3)
        let alice = makeService("@alice:example.com")
        alice.service.badgeCountPublisher = badgeCountSubject.asCurrentValuePublisher()
        notificationManager.add(alice.service)
        
        badgeCountSubject.send(7)
        
        #expect(appSettings.lastKnownBadgeCount == 7)
    }
    
    @Test("The app badge drops a removed account")
    func appBadgeRemovedAccount() {
        notificationManager.add(makeService("@alice:example.com", badgeCount: 3).service)
        notificationManager.add(makeService("@bob:example.com", badgeCount: 2).service)
        
        notificationManager.remove(userID: "@bob:example.com")
        
        #expect(appSettings.lastKnownBadgeCount == 3)
    }
    
    @Test("The app badge is left alone without an account")
    func appBadgeWithoutAccount() {
        appSettings.lastKnownBadgeCount = 4
        
        notificationManager.remove(userID: "@alice:example.com")
        
        #expect(appSettings.lastKnownBadgeCount == 4)
        #expect(!notificationCenter.setBadgeCountCalled)
    }
    
    @Test("Updating the app badge sets it on the notification center")
    func updateAppBadge() async {
        await waitForConfirmation("The app badge should be set", timeout: .seconds(10)) { confirm in
            notificationCenter.setBadgeCountClosure = { _ in confirm() }
            notificationManager.add(makeService("@alice:example.com", badgeCount: 7).service)
        }
        
        #expect(notificationCenter.setBadgeCountReceivedNewBadgeCount == 7)
    }
    
    @Test("Resetting stops receiving notifications")
    func reset() async {
        notificationManager.delegate = self
        appSettings.lastKnownBadgeCount = 4
        
        await waitForConfirmation("The app badge should be reset", timeout: .seconds(10)) { confirm in
            notificationCenter.setBadgeCountClosure = { _ in confirm() }
            notificationManager.reset()
        }
        
        #expect(notificationCenter.setBadgeCountReceivedNewBadgeCount == 0)
        #expect(appSettings.lastKnownBadgeCount == 0)
        #expect(unregisterForRemoteNotificationsDelegateCalled)
    }
    
    // MARK: - Delivered notifications
    
    @Test("Removing an account's notifications only touches that account")
    func removeNotifications() async throws {
        notificationCenter.deliveredNotificationsReturnValue = try [notification("alice room", roomID: "!room:example.com", receiverID: "@alice:example.com"),
                                                                    notification("bob room", roomID: "!room:example.com", receiverID: "@bob:example.com"),
                                                                    notification("alice other", roomID: "!other:example.com", receiverID: "@alice:example.com"),
                                                                    notification("legacy room", roomID: "!room:example.com", receiverID: nil)]
        let alice = makeService("@alice:example.com")
        notificationManager.add(alice.service)
        
        await waitForConfirmation("Notifications should be removed", timeout: .seconds(10)) { confirm in
            notificationCenter.removeDeliveredNotificationsWithIdentifiersClosure = { _ in confirm() }
            alice.actions.send(.removeDeliveredNotifications { $0.request.content.roomID == "!room:example.com" })
        }
        
        // Notifications without a receiver weren't processed by the extension, so any account may clear them.
        #expect(notificationCenter.removeDeliveredNotificationsWithIdentifiersReceivedIdentifiers == ["alice room", "legacy room"])
    }
    
    // MARK: - System
    
    @Test("Showing a local notification adds a notification request")
    func showLocalNotification() async throws {
        await notificationManager.showLocalNotification(with: "Title", subtitle: "Subtitle")
        let request = try #require(notificationCenter.addReceivedRequest)
        #expect(request.content.title == "Title")
        #expect(request.content.subtitle == "Subtitle")
    }
    
    @Test("Starting sets the notification categories")
    func notificationCategories() {
        let replyAction = UNTextInputNotificationAction(identifier: NotificationConstants.Action.inlineReply,
                                                        title: L10n.actionQuickReply,
                                                        options: [])
        let messageCategory = UNNotificationCategory(identifier: NotificationConstants.Category.message,
                                                     actions: [replyAction],
                                                     intentIdentifiers: [],
                                                     options: [])
        
        let inviteCategory = UNNotificationCategory(identifier: NotificationConstants.Category.invite,
                                                    actions: [],
                                                    intentIdentifiers: [],
                                                    options: [])
        
        let answerCallAction = UNNotificationAction(identifier: NotificationConstants.Action.answerCall,
                                                    title: L10n.actionJoin,
                                                    options: [.foreground])
        let incomingCallCategory = UNNotificationCategory(identifier: NotificationConstants.Category.incomingCall,
                                                          actions: [answerCallAction],
                                                          intentIdentifiers: [],
                                                          options: [])
        #expect(notificationCenter.setNotificationCategoriesReceivedCategories == [messageCategory, inviteCategory, incomingCallCategory])
    }
    
    @Test("Starting sets the notification center delegate")
    func notificationCenterDelegate() throws {
        let delegate = try #require(notificationCenter.delegate)
        #expect(delegate.isEqual(notificationManager))
    }
    
    @Test("Notifications are presented when there is no delegate")
    func presentationOptionsWithoutDelegate() async throws {
        let archiver = MockCoder(requiringSecureCoding: false)
        let notification = try #require(UNNotification(coder: archiver))
        let options = await notificationManager.userNotificationCenter(UNUserNotificationCenter.current(), willPresent: notification)
        #expect(options == [.badge, .sound, .list, .banner])
    }
    
    @Test("Notifications are hidden when the delegate says not to display them")
    func presentationOptionsHidden() async throws {
        shouldDisplayInAppNotificationReturnValue = false
        notificationManager.delegate = self
        
        let notification = try UNNotification.with(userInfo: [AnyHashable: Any]())
        let options = await notificationManager.userNotificationCenter(UNUserNotificationCenter.current(), willPresent: notification)
        #expect(options == [])
    }
    
    @Test("Notifications are presented when the delegate says to display them")
    func presentationOptionsShown() async throws {
        shouldDisplayInAppNotificationReturnValue = true
        notificationManager.delegate = self
        
        let notification = try UNNotification.with(userInfo: [AnyHashable: Any]())
        let options = await notificationManager.userNotificationCenter(UNUserNotificationCenter.current(), willPresent: notification)
        #expect(options == [.badge, .sound, .list, .banner])
    }
    
    @Test("An inline reply is handed to the delegate")
    func inlineReply() async throws {
        handleInlineReplyDelegateCalled = false
        notificationManager.delegate = self
        let response = try UNTextInputNotificationResponse.with(userInfo: [AnyHashable: Any](), actionIdentifier: NotificationConstants.Action.inlineReply)
        await notificationManager.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: response)
        #expect(handleInlineReplyDelegateCalled)
    }
    
    @Test("Tapping a notification is handed to the delegate")
    func notificationTapped() async throws {
        notificationTappedDelegateCalled = false
        notificationManager.delegate = self
        let response = try UNTextInputNotificationResponse.with(userInfo: [AnyHashable: Any](), actionIdentifier: UNNotificationDefaultActionIdentifier)
        await notificationManager.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: response)
        #expect(notificationTappedDelegateCalled)
    }
    
    @Test("Answering a ringing call notification is handled like tapping it")
    func answerCallAction() async throws {
        notificationTappedDelegateCalled = false
        notificationManager.delegate = self
        let response = try UNTextInputNotificationResponse.with(userInfo: [AnyHashable: Any](), actionIdentifier: NotificationConstants.Action.answerCall)
        await notificationManager.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: response)
        #expect(notificationTappedDelegateCalled)
    }
    
    // MARK: - Helpers
    
    private func makeService(_ userID: String, isEnabled: Bool = true, badgeCount: Int = 0) -> (service: NotificationServiceMock, actions: PassthroughSubject<NotificationServiceAction, Never>) {
        let actions = PassthroughSubject<NotificationServiceAction, Never>()
        let service = NotificationServiceMock(.init(userID: userID, isEnabled: isEnabled, badgeCount: badgeCount))
        service.actionsPublisher = actions.eraseToAnyPublisher()
        return (service, actions)
    }
    
    private func notification(_ identifier: String, roomID: String, receiverID: String?) throws -> UNNotification {
        var userInfo: [AnyHashable: Any] = [NotificationConstants.UserInfoKey.roomIdentifier: roomID]
        userInfo[NotificationConstants.UserInfoKey.receiverIdentifier] = receiverID
        return try UNNotification.with(userInfo: userInfo, identifier: identifier)
    }
}

extension NotificationManagerTests: @MainActor NotificationManagerDelegate {
    func registerForRemoteNotifications() {
        authorizationStatusWasGranted = true
        registerForRemoteNotificationsDelegateCalled?()
    }
    
    func unregisterForRemoteNotifications() {
        unregisterForRemoteNotificationsDelegateCalled = true
    }
    
    func shouldDisplayInAppNotification(content: UNNotificationContent) -> Bool {
        shouldDisplayInAppNotificationReturnValue
    }
    
    func notificationTapped(content: UNNotificationContent) async {
        notificationTappedDelegateCalled = true
    }
    
    func handleInlineReply(_ service: ElementX.NotificationManagerProtocol, content: UNNotificationContent, replyText: String) async {
        handleInlineReplyDelegateCalled = true
    }
}
