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

  let call = NetworkCall()
    
  @State private var log = "(no log)"
    
  var body: some View {
    VStack(spacing: 20) {
      Text("Ambilight Hue Control")

      ForEach(0..<items.count, id: \.self) { index in
        Button(action: {
          self.selection = self.items[index]
            // todo: hier den http post machen, spaeter wegen get gucken
            call.postRequest(powerState: self.items[index])
            log = call.log
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

      if let selection = selection {
        Text("Selected Item: \(selection)")
      }
        Text(log)
    }
    .padding()
  }
    
   
}


#Preview {
    ContentView()
}
