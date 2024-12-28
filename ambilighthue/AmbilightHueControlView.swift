//
//  ContentView.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import SwiftUI

struct AmbilightHueControlView: View {
    let menuItems = [("Off", AmbilightHueMode.disabled), ("On", AmbilightHueMode.enabled)]
    
    @StateObject private var ambilightTv: AmbilightTv
    
    init(ambilightTv: AmbilightTv) {
        _ambilightTv = StateObject(wrappedValue: ambilightTv)
        ambilightTv.updateState()
    }
    
  var body: some View {
    VStack(spacing: 20) {
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
    AmbilightHueControlView(ambilightTv: AmbilightTv(config: AmbilightTvConfig(), session: nil))
}
