//
//  PinEntrySheetView.swift
//  ambilighthue
//
//  Created by Silas Graffy on 12.04.25.
//

import SwiftUI
struct PinEntrySheetView<T: AmbilightTvProtocol>: View {
    @Binding var inputPin: String
    @Binding var isPairing: Bool
    @Binding var inputIp: String
    @StateObject var ambilightTv: T
    

    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter PIN")
                .font(.headline)
            
            Text("Please enter the PIN shown at your TV within the next minute")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("TV PIN", text: $inputPin)
                .keyboardType(.numbersAndPunctuation)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    inputIp = ambilightTv.config?.tvIp ?? ""
                    ambilightTv.resetPairing()
                    isPairing = false
                }
                .buttonStyle(.bordered)
                
                Button("OK") {
                    ambilightTv.confirmPairing(tvPin: inputPin, pairing: ambilightTv.pairingInProgress!)
                    isPairing = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        .padding(.horizontal, 100)
        .presentationDetents([.height(250)])
    }
}
