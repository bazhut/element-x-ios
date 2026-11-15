//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import UserNotifications

nonisolated extension UNNotificationContent {
    @objc var receiverID: String? {
        userInfo[NotificationConstants.UserInfoKey.receiverIdentifier] as? String
    }
    
    @objc var roomID: String? {
        userInfo[NotificationConstants.UserInfoKey.roomIdentifier] as? String
    }
    
    @objc var eventID: String? {
        userInfo[NotificationConstants.UserInfoKey.eventIdentifier] as? String
    }
    
    @objc var eventDate: Date? {
        userInfo[NotificationConstants.UserInfoKey.eventDate] as? Date
    }
    
    @objc var pusherNotificationClientIdentifier: String? {
        userInfo[NotificationConstants.UserInfoKey.pusherNotificationClientIdentifier] as? String
    }
    
    @objc var threadRootEventID: String? {
        userInfo[NotificationConstants.UserInfoKey.threadRootEventIdentifier] as? String
    }
    
    /// When the incoming call this notification rings for stops ringing.
    @objc var callExpirationDate: Date? {
        userInfo[NotificationConstants.UserInfoKey.callExpirationDate] as? Date
    }
    
    /// Whether the incoming call this notification rings for is voice only.
    @objc var isVoiceCall: Bool {
        userInfo[NotificationConstants.UserInfoKey.isVoiceCall] as? Bool ?? false
    }
    
    /// Whether this notification rings for an incoming call that is still ringing at the given date.
    func isRingingCall(at date: Date) -> Bool {
        guard categoryIdentifier == NotificationConstants.Category.incomingCall,
              let callExpirationDate else {
            return false
        }
        
        return date < callExpirationDate
    }
}

nonisolated extension UNMutableNotificationContent {
    override var receiverID: String? {
        get {
            userInfo[NotificationConstants.UserInfoKey.receiverIdentifier] as? String
        }
        set {
            userInfo[NotificationConstants.UserInfoKey.receiverIdentifier] = newValue
        }
    }
    
    override var roomID: String? {
        get {
            userInfo[NotificationConstants.UserInfoKey.roomIdentifier] as? String
        }
        set {
            userInfo[NotificationConstants.UserInfoKey.roomIdentifier] = newValue
        }
    }
    
    override var eventID: String? {
        get {
            userInfo[NotificationConstants.UserInfoKey.eventIdentifier] as? String
        }
        set {
            userInfo[NotificationConstants.UserInfoKey.eventIdentifier] = newValue
        }
    }
    
    override var eventDate: Date? {
        get {
            userInfo[NotificationConstants.UserInfoKey.eventDate] as? Date
        }
        set {
            userInfo[NotificationConstants.UserInfoKey.eventDate] = newValue
        }
    }
    
    override var threadRootEventID: String? {
        get {
            userInfo[NotificationConstants.UserInfoKey.threadRootEventIdentifier] as? String
        }
        set {
            userInfo[NotificationConstants.UserInfoKey.threadRootEventIdentifier] = newValue
        }
    }
    
    override var callExpirationDate: Date? {
        get {
            userInfo[NotificationConstants.UserInfoKey.callExpirationDate] as? Date
        }
        set {
            userInfo[NotificationConstants.UserInfoKey.callExpirationDate] = newValue
        }
    }
    
    override var isVoiceCall: Bool {
        get {
            userInfo[NotificationConstants.UserInfoKey.isVoiceCall] as? Bool ?? false
        }
        set {
            userInfo[NotificationConstants.UserInfoKey.isVoiceCall] = newValue
        }
    }
}
