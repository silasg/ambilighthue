//
//  NetworkCall.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import Foundation

class NetworkCall : NSObject, ObservableObject, URLSessionDelegate{
    @Published var log = "(no log)"
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.host == "TV_IP" {
            
            let urlCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)

                   completionHandler(.useCredential, urlCredential)
            
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    
    
    func postRequest(powerState: String) {
      
      
      let parameters: [String: Any] = ["power": powerState]
      
      let url = URL(string: "https://TV_IP:1926/6/HueLamp/power")! // change server url accordingly
      
        let username = "REDACTED"
        let password = "REDACTED"
       
        
   
      //let session = URLSession.shared
      
      //let session  = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        
      // now create the URLRequest object using the url object
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
        
        
        let authData = (username + ":" + password).data(using: .utf8)!.base64EncodedString()
            request.addValue("Basic \(authData)", forHTTPHeaderField: "Authorization")
        

      
      // add headers for the request
    //  request.addValue("application/json", forHTTPHeaderField: "Content-Type") // change as per server requirements
    //  request.addValue("application/json", forHTTPHeaderField: "Accept")
        
     
      do {
        // convert parameters to Data and assign dictionary to httpBody of request
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
      } catch let error {
        print(error.localizedDescription)
          self.log = error.localizedDescription
        return
      }
      
        if let body = request.httpBody {
            let convertedString = String(data: body, encoding: .utf8) ?? "invalid payload" // the data will be converted to the string
                        print(convertedString)
           
            self.log = "sending \(convertedString) ..."
          
        }
        
        // create dataTask using the session object to send data to the server
      let task = session.dataTask(with: request) { data, response, error in
        
        if let error = error {
          print("Post Request Error: \(error.localizedDescription)")
            self.log = error.localizedDescription
            return
        }
          
        
        // ensure there is valid response code returned from this HTTP response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
          print("Invalid Response received from the server")
            self.log = "invalid response"
          return
        }
        
        // ensure there is data returned
        guard let responseData = data else {
          print("nil Data received from the server")
            self.log = "nil data response"
          return
        }
        
        do {
          // create json object from data or use JSONDecoder to convert to Model stuct
          if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String: Any] {
            print(jsonResponse)
              self.log = jsonResponse.debugDescription
            // handle json response
          } else {
            print("data maybe corrupted or in wrong format")
              self.log = "data corrupted"
            throw URLError(.badServerResponse)
          }
        } catch let error {
          print(error.localizedDescription)
            self.log = error.localizedDescription
        }
      }
      // perform the task
      task.resume()
    }
}

