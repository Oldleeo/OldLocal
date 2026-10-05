import Foundation

enum ProjectChannel {
    static let repository = URL(string: "https://github.com/Oldleeo/OldLocal")!
    static let issues = repository.appendingPathComponent("issues")
    static let releases = repository.appendingPathComponent("releases")
    static let endpoint = URL(string: "https://api.github.com/repos/Oldleeo/OldLocal/releases/latest")!
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0" }
    static func feedbackURL(feature: Bool, version: String = version) -> URL {
        var url = URLComponents(url: issues.appendingPathComponent("new"), resolvingAgainstBaseURL: false)!
        let body = feature ? "## 希望解决的问题\n\n\n## 建议的功能\n\n\nOldLocal 版本：\(version)\n" :
            "## 问题描述\n\n\n## 复现步骤\n1. \n2. \n\n## 预期结果与实际结果\n\n\nOldLocal 版本：\(version)\nmacOS：\(ProcessInfo.processInfo.operatingSystemVersionString)\n架构：Apple Silicon (arm64)\n\n请在提交前检查附件与文字中的个人信息。\n"
        url.queryItems = [URLQueryItem(name: "title", value: feature ? "[建议] " : "[问题] "),
                          URLQueryItem(name: "body", value: body), URLQueryItem(name: "labels", value: feature ? "enhancement" : "bug")]
        return url.url!
    }
}

struct StableVersion: Comparable {
    let parts: [Int]
    init?(_ text: String) {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let tokens = value.split(separator: ".", omittingEmptySubsequences: false)
        guard tokens.count == 3, tokens.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0 >= "0" && $0 <= "9" }) }),
              tokens.allSatisfy({ Int($0) != nil }) else { return nil }
        parts = tokens.map { Int($0)! }
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct PublishedRelease: Decodable {
    struct Asset: Decodable { let name: String; let browser_download_url: URL }
    let tag_name: String
    let html_url: URL
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
    var download: URL? {
        assets.first(where: { ["OldLocal-macOS-arm64.zip", "OldLocal.zip"].contains($0.name) &&
            Self.isProjectURL($0.browser_download_url, prefix: "/Oldleeo/OldLocal/releases/download/") })?.browser_download_url
    }
    static func isProjectURL(_ url: URL, prefix: String) -> Bool {
        url.scheme == "https" && url.host == "github.com" && url.user == nil && url.password == nil &&
            (url.port == nil || url.port == 443) && url.path.hasPrefix(prefix)
    }
    static func decode(_ data: Data) throws -> PublishedRelease {
        guard data.count <= 1_048_576 else { throw ReleaseFailure.invalid }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard !result.draft, !result.prerelease, StableVersion(result.tag_name) != nil,
              isProjectURL(result.html_url, prefix: "/Oldleeo/OldLocal/releases/tag/") else { throw ReleaseFailure.invalid }
        return result
    }
}

enum ReleaseFailure: Error { case notPublished, rateLimited, invalid, unavailable }

enum ReleaseLookup {
    static func check(completion: @escaping (Result<PublishedRelease, Error>) -> Void) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: ProjectChannel.endpoint, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("OldLocal/" + ProjectChannel.version, forHTTPHeaderField: "User-Agent")
        session.dataTask(with: request) { data, response, error in
            defer { session.finishTasksAndInvalidate() }
            let result: Result<PublishedRelease, Error>
            if let error = error { result = .failure(error) }
            else if let response = response as? HTTPURLResponse {
                switch response.statusCode {
                case 200: result = Result { try PublishedRelease.decode(data ?? Data()) }
                case 404: result = .failure(ReleaseFailure.notPublished)
                case 403, 429: result = .failure(ReleaseFailure.rateLimited)
                default: result = .failure(ReleaseFailure.unavailable)
                }
            } else { result = .failure(ReleaseFailure.unavailable) }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
}
