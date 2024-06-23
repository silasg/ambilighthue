//
//  NetworkCall.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import Foundation

class NetworkCall : NSObject, ObservableObject, URLSessionDelegate{
    @Published var log = "(no log)"
   
    let usr = "REDACTED"
    let pwd = "REDACTED"
   
    
    
    public func urlSession(
            _ session: URLSession,
          task: URLSessionTask,
          didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        print("challenged \(task) with \(challenge)")
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            return (.useCredential, URLCredential(user: usr, password: pwd, persistence: .forSession))
        }
        return (.performDefaultHandling, nil)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            print("received task challenge")
        }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceiveChallenge challenge: URLAuthenticationChallenge, completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    print("didReceiveAuthenticationChallenge")

    }
    
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        
        if challenge.protectionSpace.host == "TV_IP" {
            let method = challenge.protectionSpace.authenticationMethod
            print("auth method \(method)")
            
            
            if method == NSURLAuthenticationMethodHTTPBasic {
                
                let urlCredential =  URLCredential(user: usr, password: pwd, persistence: .forSession)
                return completionHandler(.useCredential, urlCredential)
            } else if method == NSURLAuthenticationMethodServerTrust {
                
                let urlCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                //urlCredential.user = username
                //urlCredential.password = password
                return completionHandler(.useCredential, urlCredential)
            }
            
        } else {
           return completionHandler(.performDefaultHandling, nil)
        }
    }
    
    
    
    func postRequest(powerState: String) {
      
      
      let parameters: [String: Any] = ["power": powerState]
      
      let url = URL(string: "https://TV_IP:1926/6/HueLamp/power")! // change server url accordingly
      
        
   
      //let session = URLSession.shared
      let sessionConfig = URLSessionConfiguration.default
        
       let authData = (usr + ":" + pwd).data(using: .utf8)!.base64EncodedString()
        print(usr)
        print(pwd)
        print(authData)
        sessionConfig.httpAdditionalHeaders = ["Authorization": "Basic \(authData)"]
        
      let session  = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
       // let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        
      // now create the URLRequest object using the url object
      var request = URLRequest(url: url)
      request.httpMethod = "POST"

      
      // add headers for the request
    //  request.addValue("application/json", forHTTPHeaderField: "Content-Type") // change as per server requirements
    //  request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "accept")
               request.setValue("application/json", forHTTPHeaderField: "content-type")
              
     
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
          
        var res = response as? HTTPURLResponse
          self.log = "response code is \(res?.statusCode ?? 0)"
          print(self.log)
        // ensure there is valid response code returned from this HTTP response
       /* guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
          print("Invalid Response received from the server")
            self.log = "invalid response"
          return
        }*/
          
          if let outputStr  = String(data: data!, encoding: String.Encoding.utf8) as String?
          { self.log = outputStr }
                   
        
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

