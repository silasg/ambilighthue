//
//  ContentView.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import SwiftUI

struct AmbilightHueControlView<T: AmbilightTvProtocol>: View {
    let menuItems = [("Off", AmbilightHueMode.disabled), ("On", AmbilightHueMode.enabled)]
    
    @StateObject private var ambilightTv: T
    
    init(ambilightTv: T) {
        _ambilightTv = StateObject(wrappedValue: ambilightTv)
        ambilightTv.updateState()
    }
    
    @State private var showingAlert = false
    @State private var inputText = ""
    
  var body: some View {
    VStack(spacing: 20) {
        HStack{
            Spacer()
            Button(action: { showingAlert.toggle() })
            {Image(systemName: "gearshape.fill").padding()}
                .alert("Enter TV IP address.", isPresented: $showingAlert) {
                        TextField("", text: $inputText)
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.done)
                    Button("OK", role: .cancel) {}
                    } message: {
                        Text("Please enter your TV's IP address (not hostname). You can find it in Settings > Network & Internet > Choose the connected Wi-Fi network or using your network router's management interface.")
                    }
                .buttonStyle(CardButtonStyle())
                
        }
        Spacer()
        Text("Ambilight Hue Control")
        
        ForEach(0..<menuItems.count, id: \.self) { (index) in
            let (label, state) = menuItems[index]
            Button(action: {ambilightTv.setAmbilightHueMode(newMode: state)})
            {
                HStack {
                    Text(label).padding()
                    Spacer()
                    if ambilightTv.currentState == state {
                        Image(systemName: "checkmark").padding()
                    }
                }
            }
            .padding()
            .buttonStyle(CardButtonStyle())
        }
        
      Spacer()
    }
    .padding()
    .ignoresSafeArea()
    .background(Group {
        if ambilightTv.currentState == .enabled {
            AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]), center: .center)
        }}.ignoresSafeArea()
        )
    
  }
    
   
}


#Preview {
    AmbilightHueControlView(ambilightTv: AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled))
}
    
