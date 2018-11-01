//
//  WiremockClient.swift
//  NewWiremockClient
//
//  Created by Ted Rothrock on 6/24/17.
//  Copyright © 2017 Ted Rothrock. All rights reserved.
//

import Foundation

enum WiremockClientError: Error {
    case verficationError(String)
}

public struct WiremockClient {
    
    public static var baseURL = "http://localhost:8080"
    
    public static func postMapping(stubMapping: StubMapping) {
        guard let url = URL(string: "\(baseURL)/__admin/mappings") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.POST.rawValue
        request.httpBody = stubMapping.asData()
        _ = makeSynchronousRequest(request: request, errorMessagePrefix: "Error posting mapping")
    }
    
    public static func updateMapping(uuid: UUID, stubMapping: StubMapping) {
        guard let url = URL(string: "\(baseURL)/__admin/mappings/\(uuid.uuidString)") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.PUT.rawValue
        request.httpBody = stubMapping.asData()
        _ = makeSynchronousRequest(request: request, errorMessagePrefix: "Error updating mapping")
    }
    
    public static func deleteMapping(uuid: UUID) {
        guard let url = URL(string: "\(baseURL)/__admin/mappings/\(uuid.uuidString)") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.DELETE.rawValue
        _ = makeSynchronousRequest(request: request, errorMessagePrefix: "Error deleting mapping")
    }
    
    
    /// Verify that a request has been made to the wiremock server at least once.
    ///
    /// - Parameter mapping: the request mapping to filter on
    /// - Throws: a verfication error if there was not matching request
    public static func verify(requestMapping: RequestMapping) throws {
        let requests = findRequests(requestMapping: requestMapping)
        if requests.count < 1 {
            throw WiremockClientError.verficationError("Did not find a matching request for the \(requestMapping) pattern")
        }
    }
    
    /// Verify that a request has been made to the wiremock server a specific number of times.
    ///
    /// - Parameter mapping: the request mapping to filter on
    /// - Throws: a verfication error if the request was not matched the expected number of times
    public static func verify(expectedCount: Int, requestMapping: RequestMapping) throws {
        let requests = findRequests(requestMapping: requestMapping)
        if requests.count != expectedCount  {
            throw WiremockClientError.verficationError("Did not find a matching request for the \(requestMapping) pattern")
        }
    }
    
    /// Looks up all requests matching a given pattern
    ///
    /// - Parameter requestMapping: the request mapping to filter on
    /// - Returns: an array of LoggedRequest objects or an empty array if there was no match
    public static func findRequests(requestMapping: RequestMapping) -> [LoggedRequest] {
        guard let url = URL(string: "\(baseURL)/__admin/requests/find") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.POST.rawValue
        request.httpBody = requestMapping.asRequestData()
        let responseData =  makeSynchronousRequest(request: request, errorMessagePrefix: "Error attempting to verify a request")
        var returnRequests: [LoggedRequest] = []
        let decoder = JSONDecoder()
        if let json = responseData {
            let requests = try! decoder.decode(AllLoggedRequests.self, from: json)
            returnRequests = requests.requests
        }
        return returnRequests
    }
    
    /// This method calls to the server to see if it is up and running.
    /// If there is a mappings element returned, and no error, we should be good.
    ///
    /// - Returns: true if the server is running and ready to interact with
    public static func isServerRunning() -> Bool {
        guard let url = URL(string: "\(baseURL)/__admin/mappings") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.GET.rawValue
        let responseData = makeSynchronousRequest(request: request, errorMessagePrefix: "Received an error from the server")
        if let responseData = responseData, let responseString = String(data: responseData, encoding: .utf8) {
            return responseString.contains("\"mappings\" :")
        }
        return false
    }
    
    public static func saveAllMappings() {
        postCommandToServer(urlCommand: "__admin/mappings/save", errorMessagePrefix: "Error saving all mappings")
    }
    
    public static func reset() {
        postCommandToServer(urlCommand: "__admin/reset", errorMessagePrefix: "Error deleting all mappings")
    }
    
    public static func resetAllScenarios() {
        postCommandToServer(urlCommand: "__admin/scenarios/reset", errorMessagePrefix: "Error resetting all scenarios")
    }
    
    public static func shutdownServer()  {
        postCommandToServer(urlCommand: "__admin/shutdown", errorMessagePrefix: "Error shutting down the server")
    }
    
    /// MARK: Private methods
    
    private static func postCommandToServer(urlCommand: String, errorMessagePrefix: String) {
        guard let url = URL(string: "\(baseURL)/\(urlCommand)") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.POST.rawValue
        _ = makeSynchronousRequest(request: request, errorMessagePrefix: errorMessagePrefix)
    }
    
    private static func makeSynchronousRequest(request: URLRequest, errorMessagePrefix: String) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data? = nil
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("\(errorMessagePrefix): \(error.localizedDescription)")
            } else {
                responseData = data
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        return responseData
    }

    
}
