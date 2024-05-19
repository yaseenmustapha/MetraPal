//
//  APIService.swift
//  MetraPal
//
//  Created by Yaseen Mustapha on 5/19/24.
//

import Foundation

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://gtfsapi.metrarail.com/gtfs"
    private let username = "24adf46e6f327dfbf5510fa8eb4bd625"
    private let password = "475115b80ded9d9944b0f0d50a3e6835"
//    private let username = Bundle.main.object(forInfoDictionaryKey: "METRA_API_USERNAME")! as! String
//    private let password = Bundle.main.object(forInfoDictionaryKey: "METRA_API_PASSWORD")! as! String
    
    func fetchData<T: Decodable>(from endpoint: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            completion(.failure(NSError(domain: "EncodingError", code: 0, userInfo: nil)))
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decodedData = try decoder.decode(T.self, from: data)
                completion(.success(decodedData))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
