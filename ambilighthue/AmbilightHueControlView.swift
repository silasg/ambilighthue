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
    }
    
    @State private var showingSettings = false
    @State private var askSettings = false
   
  var body: some View {
    VStack(spacing: 20) {
        HStack{
            Spacer()
            Button(action: { showingSettings.toggle() })
            {Image(systemName: "gearshape.fill").padding()}
                .sheet(isPresented: $showingSettings) {
                    SettingsView(ambilightTv:ambilightTv)
                        }
                .buttonStyle(CardButtonStyle())
                
        }
        Spacer()
        Text("Ambilight Hue Control").font(.headline)
        
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
            .disabled(!ambilightTv.isConfigured)
            .buttonStyle(CardButtonStyle())
        }
        
      Spacer()
    }
    .padding()
    .ignoresSafeArea()
    .background(Group {
        if ambilightTv.currentState == .enabled {
            AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]), center: .center)
        }}
        .ignoresSafeArea())
    .onAppear {
        print("is configured \(ambilightTv.isConfigured)")
        if (ambilightTv.isConfigured) {
            ambilightTv.updateState()
        }
        else {
            askSettings = true
        }
    }
    .alert(isPresented: $askSettings) {
        Alert(
            title: Text("TV not configured"),
            message: Text("The connection to TV needs to be configured to use this app. Do you want to configure it now?"),
            primaryButton: .default(Text("Yes")) {
                showingSettings.toggle()
            },
            secondaryButton: .cancel(Text("No")) {
                
            }
        )
    }
  }
    
   
}


#Preview {
    AmbilightHueControlView(ambilightTv: AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled))
}
    
