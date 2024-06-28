//
//  ContentView.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import SwiftUI

struct ContentView: View {
    let items = [("Off", AmbilightHueMode.disabled), ("On", AmbilightHueMode.enabled)]
  @StateObject private var call = NetworkCall()
    
  var body: some View {
    VStack(spacing: 20) {
        Spacer()
        Text("Ambilight Hue Control")
        
        ForEach(0..<items.count, id: \.self) { (index) in
            let (label, state) = items[index]
            Button(action: {call.postRequest(newState: state)})
            {
                HStack {
                    Text(label).padding()
                    Spacer()
                    if call.currentState == state {
                        Image(systemName: "checkmark").padding()
                    }
                }
            }
            .padding()
            .buttonStyle(CardButtonStyle())
        }
        

      //Text(call.log)
      Spacer()
    }
    .padding()
    .ignoresSafeArea()
    .background(Group {
        if call.currentState == .enabled {
            AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]), center: .center)
        }}.ignoresSafeArea()
        )
    
  }
    
   
}


#Preview {
    ContentView()
}
