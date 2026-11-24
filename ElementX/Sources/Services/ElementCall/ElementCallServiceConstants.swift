//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The incoming call a VoIP push carries from the NSE to the app.
nonisolated struct VoIPPushPayload {
    /// Internal rather than private so tests can build pushes with a field missing.
    enum Key: String {
        case roomID
        case roomDisplayName
        /// When an incoming call is set to ring, there will be a `m.rtc.notification`event  (MSC4075).
        /// Keep the notification event id as it is needed to decline calls (MSC4310).
        case rtcNotifyEventID
        /// The Date at which the incoming call should stop ringing.
        case expirationDate
        case isVoiceCall
        /// The user ID of the account the call is for.
        case receiverID
    }
    
    let roomID: String
    let roomDisplayName: String?
    let rtcNotificationID: String
    let receiverID: String
    let expirationDate: Date
    let isVoiceCall: Bool
    
    /// The payload the NSE hands to `CXProvider.reportNewIncomingVoIPPushPayload(_:)`.
    var dictionary: [String: Any] {
        var dictionary: [String: Any] = [Key.roomID.rawValue: roomID,
                                         Key.rtcNotifyEventID.rawValue: rtcNotificationID,
                                         Key.receiverID.rawValue: receiverID,
                                         Key.expirationDate.rawValue: expirationDate,
                                         Key.isVoiceCall.rawValue: isVoiceCall]
        dictionary[Key.roomDisplayName.rawValue] = roomDisplayName
        return dictionary
    }
    
    init(roomID: String, roomDisplayName: String?, rtcNotificationID: String, receiverID: String, expirationDate: Date, isVoiceCall: Bool) {
        self.roomID = roomID
        self.roomDisplayName = roomDisplayName
        self.rtcNotificationID = rtcNotificationID
        self.receiverID = receiverID
        self.expirationDate = expirationDate
        self.isVoiceCall = isVoiceCall
    }
    
    init?(dictionary: [AnyHashable: Any]) {
        guard let roomID = dictionary[Key.roomID.rawValue] as? String,
              let rtcNotificationID = dictionary[Key.rtcNotifyEventID.rawValue] as? String,
              let receiverID = dictionary[Key.receiverID.rawValue] as? String,
              let expirationDate = Self.date(from: dictionary[Key.expirationDate.rawValue]) else {
            return nil
        }
        
        self.init(roomID: roomID,
                  roomDisplayName: dictionary[Key.roomDisplayName.rawValue] as? String,
                  rtcNotificationID: rtcNotificationID,
                  receiverID: receiverID,
                  expirationDate: expirationDate,
                  isVoiceCall: dictionary[Key.isVoiceCall.rawValue] as? Bool ?? false)
    }
    
    /// The body of a push gateway request that rings this call through PushKit on the device with the given token.
    ///
    /// The NSE sends it when CallKit can't be reached from the extension. The push gateway puts the
    /// `default_payload` in the VoIP push, so the payload is encoded with JSON types only.
    func pushGatewayRequestBody(appID: String, pushKey: String) throws -> Data {
        var payload: [String: Any] = [Key.roomID.rawValue: roomID,
                                      Key.rtcNotifyEventID.rawValue: rtcNotificationID,
                                      Key.receiverID.rawValue: receiverID,
                                      Key.expirationDate.rawValue: expirationDate.timeIntervalSince1970,
                                      Key.isVoiceCall.rawValue: isVoiceCall]
        payload[Key.roomDisplayName.rawValue] = roomDisplayName
        
        let device: [String: Any] = ["app_id": appID,
                                     "pushkey": pushKey,
                                     "data": ["default_payload": payload]]
        let notification: [String: Any] = ["event_id": rtcNotificationID,
                                           "room_id": roomID,
                                           "prio": "high",
                                           "devices": [device]]
        
        return try JSONSerialization.data(withJSONObject: ["notification": notification])
    }
    
    /// Reads a date from the NSE, or a timestamp from a push sent through the push gateway.
    private static func date(from value: Any?) -> Date? {
        if let date = value as? Date {
            date
        } else if let timestamp = value as? TimeInterval {
            Date(timeIntervalSince1970: timestamp)
        } else {
            nil
        }
    }
}

nonisolated let ElementCallServiceNotificationDiscardDelta = 15.0
