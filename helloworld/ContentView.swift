//
//  ContentView.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import SwiftUI

struct ContentView: View {
  let items = ["Off", "On"]
  @State private var selection: String? = nil

    @StateObject private var call = NetworkCall()
    
    
  var body: some View {
    VStack(spacing: 20) {
      Text("Ambilight Hue Control")

      ForEach(0..<items.count, id: \.self) { index in
        Button(action: {
          self.selection = self.items[index]
            // todo: hier den http post machen, spaeter wegen get gucken
            call.postRequest(powerState: self.items[index])
        }) {
          HStack {
            Text(self.items[index])
            Spacer()
            if selection == self.items[index] {
              Image(systemName: "checkmark")
            }
          }
        }
        .padding()
      }

      Text(call.log)
    }
    .padding()
  }
    
   
}


#Preview {
    ContentView()
}
