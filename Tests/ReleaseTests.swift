import Foundation

@main struct ReleaseTests {
    static func main() throws {
        precondition(StableVersion("v2.10.0")! > StableVersion("2.9.9")!)
        precondition(StableVersion("2.3.0")! == StableVersion("v2.3.0")!)
        for value in ["2.3", "2..3", "2.3.0-beta", "2.3.-1", "../../2", "9999999999999999999999.1.1"] { precondition(StableVersion(value) == nil) }
        let release: [String: Any] = ["tag_name": "v2.3.0", "html_url": "https://github.com/Oldleeo/OldLocal/releases/tag/v2.3.0", "body": "Release notes", "draft": false, "prerelease": false,
            "assets": [["name": "OldLocal-macOS-arm64.zip", "browser_download_url": "https://github.com/Oldleeo/OldLocal/releases/download/v2.3.0/OldLocal-macOS-arm64.zip"]]]
        let parsed = try PublishedRelease.decode(JSONSerialization.data(withJSONObject: release))
        precondition(parsed.download != nil)
        for (key, value) in [("draft", true as Any), ("prerelease", true as Any), ("tag_name", "v2.3.0-beta" as Any), ("html_url", "https://github.com/other/repo/releases/tag/v2.3.0" as Any)] {
            var bad = release; bad[key] = value
            do { _ = try PublishedRelease.decode(JSONSerialization.data(withJSONObject: bad)); preconditionFailure("Invalid release accepted") } catch {}
        }
        var badAsset = release
        badAsset["assets"] = [["name": "OldLocal-macOS-arm64.zip", "browser_download_url": "https://example.com/app.zip"]]
        let withoutDownload = try PublishedRelease.decode(JSONSerialization.data(withJSONObject: badAsset))
        precondition(withoutDownload.download == nil)
        let feedback = ProjectChannel.feedbackURL(feature: false, version: "2.3.0")
        precondition(feedback.host == "github.com" && feedback.path == "/Oldleeo/OldLocal/issues/new")
        let body = URLComponents(url: feedback, resolvingAgainstBaseURL: false)!.queryItems!.first(where: { $0.name == "body" })!.value!
        precondition(body.contains("2.3.0") && !body.contains("101.705500") && !body.contains("favorites.json"))
        print("PASS: version ordering, stable release validation, repository download restriction, feedback URL encoding")
    }
}
