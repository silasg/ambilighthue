//
//  SettingsView.swift
//  ambilighthue
//
//  Created by Silas Graffy on 01.03.25.
//


import SwiftUI

struct SettingsView<T: AmbilightTvProtocol>: View {
    @StateObject private var ambilightTv: T
    @State private var inputIp = ""
    @State private var inputDisabled = ""
    @State private var inputPin = ""
    @State private var showResetAlert = false
    @State private var isPairing = false
    @FocusState private var isIpInputFocused: Bool
    @Environment(\.dismiss) var dismiss
    
    init(ambilightTv: T) {
        _ambilightTv = StateObject(wrappedValue: ambilightTv)
    }
    
    var body: some View {
        VStack() {
            Spacer()
            HStack(spacing: 2) {
                Text("Ambilight Hue Control Settings ").font(.headline)
                Image(systemName: "gearshape.fill").padding()
            }
            Text("Please enter your TV's IP address (not hostname). You can find it in Settings > Network & Internet > Choose the connected Wi-Fi network or using your network router's management interface.")
            HStack {
                Label("TV IP", systemImage: "").labelStyle(.titleOnly).frame(width: 250, alignment: .trailing)
                TextField("TV IP Address", text: $inputIp)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($isIpInputFocused)
                    .onChange(of: isIpInputFocused, initial: false) { focused, arguments  in
                        if !focused && ambilightTv.config?.tvIp != inputIp {
                            ambilightTv.startPairing(tvIp: inputIp)
                        }
                    }
                    .onChange(of: ambilightTv.pairingInProgress != nil, { oldValue, newValue in
                        if ambilightTv.pairingInProgress != nil {
                            isPairing = true
                        }
                    })
                    .alert("Enter PIN", isPresented: $isPairing) {
                        TextField("", text: $inputPin).keyboardType(.numbersAndPunctuation)
                            Button("OK", action: {
                                ambilightTv.confirmPairing(tvPin: inputPin, pairing: ambilightTv.pairingInProgress!)
                                isPairing = false
                            })
                            Button("Cancel", role: .cancel) {
                                inputIp = ambilightTv.config?.tvIp ?? ""
                                ambilightTv.resetPairing()
                                isPairing = false
                            }
                        }
                        message: {
                            Text("Please enter the PIN shown at your TV within the next minute")
                        }
            }
            HStack {
                Label("TV API user", systemImage: "").labelStyle(.titleOnly).frame(width: 250, alignment: .trailing)
                TextField(ambilightTv.config?.username ?? "TV API user will be shown here", text: $inputDisabled).disabled(true)
            }
            HStack {
                Label("TV API secret", systemImage: "").labelStyle(.titleOnly).frame(width: 250, alignment: .trailing)
                TextField(ambilightTv.config?.password ?? "TV API secret will be shown here", text: $inputDisabled).disabled(true)
            }

            HStack() {
                Button("Reset") { showResetAlert = true }
                    .alert(isPresented: $showResetAlert) {
                        Alert(
                            title: Text("Reset Settings"),
                            message: Text("This will reset all settings. You will need to pair your TV again. Continue?"),
                            primaryButton: .default(Text("Continue")) {
                                resetSettings()
                            },
                            secondaryButton: .cancel(Text("Cancel")) {
                                
                            }
                        )
                    }
                Button("Close", role: .cancel) { dismiss() }
            }
            Spacer()
            Text("Latest log entries:").font(.headline)
            Text(ambilightTv.log).lineLimit(2...4)
            Spacer()
        }.padding(.horizontal, 100)
            .onAppear() {
                if (ambilightTv.isConfigured) {
                    inputIp = ambilightTv.config!.tvIp
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
