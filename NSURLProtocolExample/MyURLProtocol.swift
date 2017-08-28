//
//  MyURLProtocol.swift
//  NSURLProtocolExample
//
//  Created by Chung Tran on 26/08/2017.
//  Copyright © 2017 Zedenem. All rights reserved.
//
import UIKit
import CoreData

var requestCount = 0

class MyURLProtocol: URLProtocol, URLSessionDataDelegate, URLSessionTaskDelegate {
    var dataTask: URLSessionDataTask!
    var receivedData: NSMutableData!
    var urlResponse: URLResponse?
    class var HandledKey: String {
        return "MyURLProtocolHandledKey"
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: HandledKey, in: request) != nil {
            return false
        }
        requestCount += 1
        print("Request #\(requestCount). URL: \(request.url!.absoluteString)")
        
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, to: b)
    }
    
    override func startLoading() {
        if let cachedResponse = self.cachedResponseForCurrentRequest() {
            print("Retrieve from cache...")
            let data = cachedResponse.value(forKey: "data") as? Data
//            print("Data: \(data)")
            let mimeType = cachedResponse.value(forKey: "mimeType") as? String
            let encoding = cachedResponse.value(forKey: "encoding") as? String
            
            let response = URLResponse(url: request.url!, mimeType: mimeType, expectedContentLength: data?.count ?? 0, textEncodingName: encoding)
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data ?? Data())
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        let newRequest = NSMutableURLRequest(url: self.request.url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 240.0)
        URLProtocol.setProperty(true, forKey: MyURLProtocol.HandledKey, in: newRequest)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: self.request)
        dataTask.resume()
    }
    
    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }
    
    // MARK: - URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
        receivedData.append(data)
//                    print("Data: \(receivedData)")

    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        urlResponse = response
        receivedData = NSMutableData()
        completionHandler(.allow)
    }
    
    // MARK: - URLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        // Do what ever you want like saveCachedResponse()
        client?.urlProtocolDidFinishLoading(self)
        saveCachedResponse()
    }
    
    // MARK: - Custom methods
    func saveCachedResponse() {
        DispatchQueue.main.sync {
            print("Saving cached response...")
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.managedObjectContext!
            let cachedResponse = NSEntityDescription.insertNewObject(forEntityName: "CachedURLResponse", into: context) as NSManagedObject
            cachedResponse.setValue(self.receivedData, forKey: "data")
            cachedResponse.setValue(self.request.url?.absoluteString, forKey: "url")
            cachedResponse.setValue(NSDate(), forKey: "timestamp")
            cachedResponse.setValue(self.urlResponse?.mimeType, forKey: "mimeType")
            cachedResponse.setValue(self.urlResponse?.textEncodingName, forKey: "encoding")
            appDelegate.saveContext()
        }
    }
    
    func cachedResponseForCurrentRequest() -> NSManagedObject? {
        var object: NSManagedObject?
        DispatchQueue.main.sync {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.managedObjectContext!
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CachedURLResponse")
            
            // 3
            let predicate = NSPredicate(format:"url == %@", self.request.url!.absoluteString)
            fetchRequest.predicate = predicate
            
            do {
                let result = try context.fetch(fetchRequest)
                if !result.isEmpty {
                    object = result[0]
                }
            } catch let error {
                print(error.localizedDescription)
            }
            
        }
        return object
    }
}
