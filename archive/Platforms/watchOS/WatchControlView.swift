//
//  WatchControlView.swift
//  ambilighthue-watchOS
//
//  Minimal watch UI: a status line plus On/Off buttons. When the TV is not yet
//  configured, the watch tells the user to pair on the iPhone (pairing is
//  iPhone-only by design — see the ADR).
//

import SwiftUI
import AmbilightCore

struct WatchControlView<T: AmbilightTvProtocol>: View {
    @StateObject private var ambilightTv: T

    init(ambilightTv: T) {
        _ambilightTv = StateObject(wrappedValue: ambilightTv)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Ambilight Hue").font(.headline)

            if ambilightTv.isConfigured {
                statusText

                Button {
                    ambilightTv.setAmbilightHueMode(newMode: .enabled)
                } label: {
                    Label("On", systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)

                Button {
                    ambilightTv.setAmbilightHueMode(newMode: .disabled)
                } label: {
                    Label("Off", systemImage: "lightbulb.slash")
                        .frame(maxWidth: .infinity)
                }
                .tint(.gray)
            } else {
                Text("Not configured")
                    .font(.subheadline)
                Text("Pair your TV in the iPhone app first.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            if ambilightTv.isConfigured {
                ambilightTv.updateState()
            }
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch ambilightTv.currentState {
        case .enabled:
            Text("Status: On").foregroundStyle(.green)
        case .disabled:
            Text("Status: Off").foregroundStyle(.secondary)
        case nil:
            Text("Status: —").foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchControlView(ambilightTv: AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled))
}
