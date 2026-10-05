import Foundation
import Darwin

struct IPLocation: Decodable {
    let ip: String
    let latitude: Double
    let longitude: Double
    let city: String?
    let region: String?
    let country_name: String?
    var coordinates: Coordinates { Coordinates(latitude: latitude, longitude: longitude) }
    var place: String { [city, region, country_name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ") }
}

enum IPLookupFailure: Error { case invalidIP, unavailable, rateLimited, malformed }
struct IPLookup {
    static func endpoint(for raw: String?) throws -> URL {
        guard let input = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else { return URL(string: "https://ipapi.co/json/")! }
        var v4 = in_addr(); var v6 = in6_addr()
        guard inet_pton(AF_INET, input, &v4) == 1 || inet_pton(AF_INET6, input, &v6) == 1 else { throw IPLookupFailure.invalidIP }
        var url = URLComponents(string: "https://ipapi.co")!
        url.path = "/" + input + "/json/"
        return url.url!
    }
    static func decode(_ data: Data) throws -> IPLocation {
        let value = try JSONDecoder().decode(IPLocation.self, from: data)
        guard value.latitude.isFinite, value.longitude.isFinite,
              (-90...90).contains(value.latitude), (-180...180).contains(value.longitude) else { throw IPLookupFailure.malformed }
        return value
    }
    static func query(ip: String?, completion: @escaping (Result<IPLocation, Error>) -> Void) {
        do {
            let url = try endpoint(for: ip)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 20
            let session = URLSession(configuration: configuration)
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("OldLocal/2.2", forHTTPHeaderField: "User-Agent")
            session.dataTask(with: request) { data, response, error in
                defer { session.finishTasksAndInvalidate() }
                let result: Result<IPLocation, Error>
                do {
                    if let error = error { throw error }
                    guard let http = response as? HTTPURLResponse else { throw IPLookupFailure.unavailable }
                    if http.statusCode == 429 { throw IPLookupFailure.rateLimited }
                    guard http.statusCode == 200, let data = data, data.count <= 65536 else { throw IPLookupFailure.unavailable }
                    result = .success(try decode(data))
                } catch { result = .failure(error) }
                DispatchQueue.main.async { completion(result) }
            }.resume()
        } catch { DispatchQueue.main.async { completion(.failure(error)) } }
    }
}
