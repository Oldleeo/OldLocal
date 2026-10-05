import Foundation
import Darwin

@main
struct FeatureTests {
    static func check(_ passed: Bool) { precondition(passed) }
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        let store = FavoritesStore(url: directory.appendingPathComponent("favorites.json"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID()
        let legacy = "[{\"id\":\"\(id.uuidString)\",\"note\":\"旧版收藏\",\"coordinates\":{\"latitude\":3.179366,\"longitude\":101.703734}}]"
        try Data(legacy.utf8).write(to: store.url)
        let migrated = try store.load()
        precondition(migrated[0].id == id && migrated[0].group == "未分组" && migrated[0].note == "旧版收藏")
        var a = migrated[0]; a.group = "旅行"
        let b = Favorite(id: UUID(), note: "公司", coordinates: Coordinates(latitude: 1, longitude: 2), group: "工作")
        let c = Favorite(id: UUID(), note: "旅行地点", coordinates: Coordinates(latitude: 4, longitude: 5), group: "旅行")
        let items = [a,b,c]
        let reordered = FavoriteOrdering.moving(items, id: c.id, before: a.id)
        precondition(reordered.map(\.id) == [c.id,a.id,b.id])
        precondition(FavoriteOrdering.moving(items, id: a.id, before: a.id) == items)
        let down = FavoriteOrdering.moving(items, id: a.id, before: nil, after: c.id)
        precondition(down.map(\.id) == [b.id,c.id,a.id])
        try store.save(reordered)
        check(try store.load() == reordered)
        let remaining = try store.moveToTrash(a, from: reordered)
        precondition(!remaining.contains(where: { $0.id == a.id }))
        check(try store.trash.load() == [a])
        let restored = try store.restoring(a, into: remaining)
        precondition(restored.contains(a))
        check(try store.load() == restored)
        check(try store.trash.load().isEmpty)
        check(try IPLookup.endpoint(for: nil).absoluteString == "https://ipapi.co/json/")
        check(try IPLookup.endpoint(for: "8.8.8.8").absoluteString == "https://ipapi.co/8.8.8.8/json/")
        _ = try IPLookup.endpoint(for: "2001:4860:4860::8888")
        for text in ["8.8.8.8/../../", "x.com", "1.2.3.999", "https://example.com", "$(id)"] {
            do { _ = try IPLookup.endpoint(for: text); preconditionFailure("Bad IP accepted") } catch IPLookupFailure.invalidIP {}
        }
        let result = try IPLookup.decode(Data("{\"ip\":\"8.8.8.8\",\"latitude\":37.4,\"longitude\":-122.1,\"city\":\"Mountain View\"}".utf8))
        precondition(result.coordinates == Coordinates(latitude: 37.4, longitude: -122.1))
        do { _ = try IPLookup.decode(Data("{\"ip\":\"8.8.8.8\",\"latitude\":91,\"longitude\":2}".utf8)); preconditionFailure("Bad latitude accepted") } catch {}
        print("PASS: legacy migration, grouped ordering, persisted sorting, recoverable deletion, IP validation and decoding")
        if CommandLine.arguments.contains("--live") {
            var done = false
            var success = false
            IPLookup.query(ip: "8.8.8.8") { result in
                if case .success(let location) = result { success = location.ip == "8.8.8.8" }
                else { print("Live public-IP lookup unavailable") }
                done = true
            }
            let deadline = Date().addingTimeInterval(25)
            while !done, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
            guard done && success else { print("LIVE NOT VERIFIED: provider did not return a valid response"); exit(2) }
            print("PASS: HTTPS lookup of public test IP 8.8.8.8")
        }
    }
}
