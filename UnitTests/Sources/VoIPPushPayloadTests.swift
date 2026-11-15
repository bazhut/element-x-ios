//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

struct VoIPPushPayloadTests {
    private let payload = VoIPPushPayload(roomID: "!room:example.com",
                                          roomDisplayName: "Alice",
                                          rtcNotificationID: "$notification",
                                          receiverID: "@bob:example.com",
                                          expirationDate: Date(timeIntervalSince1970: 1_800_000_000),
                                          isVoiceCall: true)
    
    @Test("A call rung through the push gateway reaches the app with all its details")
    func pushGatewayRoundTrip() throws {
        let notification = try notification(in: payload.pushGatewayRequestBody(appID: "io.element.ios.voip.dev", pushKey: "token"))
        let devices = try #require(notification["devices"] as? [[String: Any]])
        let data = try #require(devices.first?["data"] as? [String: Any])
        var voipPush = try #require(data["default_payload"] as? [String: Any])
        // The push gateway adds the room and event IDs to the default payload of an event ID only push.
        voipPush["room_id"] = notification["room_id"]
        voipPush["event_id"] = notification["event_id"]
        
        let receivedPayload = try #require(VoIPPushPayload(dictionary: voipPush))
        
        #expect(receivedPayload.roomID == payload.roomID)
        #expect(receivedPayload.roomDisplayName == payload.roomDisplayName)
        #expect(receivedPayload.rtcNotificationID == payload.rtcNotificationID)
        #expect(receivedPayload.receiverID == payload.receiverID)
        #expect(receivedPayload.expirationDate == payload.expirationDate)
        #expect(receivedPayload.isVoiceCall)
    }
    
    @Test("The push gateway request targets this device's VoIP pusher with a high priority")
    func pushGatewayRequest() throws {
        let notification = try notification(in: payload.pushGatewayRequestBody(appID: "io.element.ios.voip.dev", pushKey: "token"))
        let devices = try #require(notification["devices"] as? [[String: Any]])
        
        #expect(notification["event_id"] as? String == "$notification")
        #expect(notification["room_id"] as? String == "!room:example.com")
        #expect(notification["prio"] as? String == "high")
        #expect(notification["type"] == nil)
        #expect(devices.count == 1)
        #expect(devices.first?["app_id"] as? String == "io.element.ios.voip.dev")
        #expect(devices.first?["pushkey"] as? String == "token")
    }
    
    @Test("A payload handed over by the NSE is read with its date")
    func notificationServiceExtensionPayload() throws {
        let receivedPayload = try #require(VoIPPushPayload(dictionary: payload.dictionary))
        
        #expect(receivedPayload.expirationDate == payload.expirationDate)
        #expect(receivedPayload.isVoiceCall)
    }
    
    @Test("A push without an expiration date is rejected")
    func missingExpirationDate() {
        var dictionary = payload.dictionary
        dictionary[VoIPPushPayload.Key.expirationDate.rawValue] = nil
        
        #expect(VoIPPushPayload(dictionary: dictionary) == nil)
    }
    
    // MARK: - Helpers
    
    private func notification(in body: Data) throws -> [String: Any] {
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        return try #require(json["notification"] as? [String: Any])
    }
}
