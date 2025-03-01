//
//  SettingsView.swift
//  ambilighthue
//
//  Created by Silas Graffy on 01.03.25.
//


import SwiftUI

struct SettingsView: View {
    @State private var inputIp = ""
    @State private var inputUser = ""
    @State private var inputPass = ""
    @State private var inputPin = ""
    @State private var showResetAlert = false
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) var dismiss
    
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
                    .focused($isFocused)
                    .onChange(of: isFocused, initial: false) { focused, arguments  in
                        if !focused {
                            // TODO: compare with current IP and in case of change start pairing and ask for pin
                            print("Text changed to: \(inputIp) - \(arguments)")
                        }
                    }
            }
            HStack {
                Label("TV API user", systemImage: "").labelStyle(.titleOnly).frame(width: 250, alignment: .trailing)
                TextField("TV API user will be shown here", text: $inputUser).disabled(true)
            }
            HStack {
                Label("TV API secret", systemImage: "").labelStyle(.titleOnly).frame(width: 250, alignment: .trailing)
                TextField("TV API secret will be shown here", text: $inputPass).disabled(true)
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
        }.padding(.horizontal, 100)
    }
    
    func resetSettings() {
        inputIp = ""
        inputUser = ""
        inputPass = ""
        inputPin = ""
        showResetAlert = false
    }
}
