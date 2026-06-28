//
//  SettingsView.swift
//  ambilighthue-iOS  (universal: iPhone + iPad)
//
//  iOS-adapted port of the tvOS settings view. Uses a Form for an iOS-native
//  look. The pairing flow is unchanged: editing the TV IP and leaving the field
//  starts pairing, which surfaces a PIN-entry alert; the granted credentials are
//  then persisted. Reset clears the stored config.
//

import SwiftUI
import AmbilightCore

struct SettingsView<T: AmbilightTvProtocol>: View {
    @StateObject private var ambilightTv: T
    @State private var inputIp = ""
    @State private var inputPin = ""
    @State private var showResetAlert = false
    @State private var isPairing = false
    @FocusState private var isIpInputFocused: Bool
    @Environment(\.dismiss) var dismiss

    init(ambilightTv: T) {
        _ambilightTv = StateObject(wrappedValue: ambilightTv)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Please enter your TV's IP address (not hostname). You can find it in Settings > Network & Internet > Choose the connected Wi-Fi network or using your network router's management interface.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("TV connection") {
                    HStack {
                        Text("TV IP")
                        Spacer()
                        TextField("TV IP Address", text: $inputIp)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .focused($isIpInputFocused)
                            .onChange(of: isIpInputFocused, initial: false) { _, focused in
                                if !focused && ambilightTv.config?.tvIp != inputIp {
                                    ambilightTv.startPairing(tvIp: inputIp)
                                }
                            }
                            .onChange(of: ambilightTv.pairingInProgress != nil) { _, _ in
                                if ambilightTv.pairingInProgress != nil {
                                    isPairing = true
                                }
                            }
                    }

                    HStack {
                        Text("TV API user")
                        Spacer()
                        Text(ambilightTv.config?.username ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("TV API secret")
                        Spacer()
                        Text(ambilightTv.config?.password ?? "—")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Section {
                    Button("Reset", role: .destructive) { showResetAlert = true }
                }

                Section("Latest log entry") {
                    Text(ambilightTv.log).font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Enter PIN", isPresented: $isPairing) {
                TextField("PIN", text: $inputPin).keyboardType(.numbersAndPunctuation)
                Button("OK") {
                    if let pairing = ambilightTv.pairingInProgress {
                        ambilightTv.confirmPairing(tvPin: inputPin, pairing: pairing)
                    }
                    isPairing = false
                }
                Button("Cancel", role: .cancel) {
                    inputIp = ambilightTv.config?.tvIp ?? ""
                    ambilightTv.resetPairing()
                    isPairing = false
                }
            } message: {
                Text("Please enter the PIN shown at your TV within the next minute")
            }
            .alert("Reset Settings", isPresented: $showResetAlert) {
                Button("Continue", role: .destructive) { resetSettings() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all settings. You will need to pair your TV again. Continue?")
            }
            .onAppear {
                if ambilightTv.isConfigured {
                    inputIp = ambilightTv.config!.tvIp
                }
            }
        }
    }

    func resetSettings() {
        inputIp = ""
        inputPin = ""
        showResetAlert = false
        ambilightTv.resetPairing()
    }
}

#Preview {
    SettingsView(ambilightTv: AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled))
}
