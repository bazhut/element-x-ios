//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import ElementCall
import SwiftUI

/// The bar above the app's screens while a native call is minimized, following the call's room and duration.
struct NativeCallInProgressBar: View {
    let controller: ElementCallController
    let action: () -> Void
    
    var body: some View {
        CallInProgressBar(roomName: controller.room?.displayName,
                          connectedAt: controller.connectedAt,
                          action: action)
    }
}

/// A bar that leads back to a minimized call, showing its room and how long it has been connected.
struct CallInProgressBar: View {
    let roomName: String?
    let connectedAt: Date?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CompoundIcon(\.voiceCallSolid, size: .small, relativeTo: .compound.bodyMDSemibold)
                
                Text(roomName ?? L10n.commonCallInProgress)
                    .font(.compound.bodyMDSemibold)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                if let connectedAt {
                    Text(timerInterval: connectedAt...Date.distantFuture, countsDown: false)
                        .font(.compound.bodyMDSemibold)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(Color.compound.textOnSolidPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.compound.bgAccentRest.ignoresSafeArea(edges: .top))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([L10n.commonCallInProgress, roomName].compactMap(\.self).joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}

struct CallInProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            CallInProgressBar(roomName: "Alice", connectedAt: .now.addingTimeInterval(-42)) { }
            CallInProgressBar(roomName: nil, connectedAt: nil) { }
        }
    }
}
