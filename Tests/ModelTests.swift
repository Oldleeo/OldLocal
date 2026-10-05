import Foundation

@main
struct ModelTests {
    static func check(_ passed: Bool) { precondition(passed) }
    static func main() throws {
        let value = Coordinates.parse("3.178400, 101.705500")!
        precondition(value.latitude == 3.1784 && value.longitude == 101.7055)
        precondition(value.text == "3.178400, 101.705500")
        precondition(Coordinates.parse(" 3.178400， 101.705500\n") == value)
        precondition(Coordinates.parse("−90, -180") == Coordinates(latitude: -90, longitude: -180))
        precondition(Coordinates.parse("90, 180") != nil)
        for invalid in ["", "3.1", "3.1,", ",101", "1,2,3", "91,0", "0,181", "NaN,0", "0,inf", "$(id),2"] {
            precondition(Coordinates.parse(invalid) == nil, invalid)
        }
        let store = FavoritesStore(url: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("favorites.json"))
        check(try store.load().isEmpty)
        var items = [Favorite(id: UUID(), note: "公司 · 中文备注", coordinates: value)]
        try store.save(items)
        check(try store.load() == items)
        items[0].note = "更新后的备注"
        items[0].coordinates = Coordinates(latitude: 48.8584, longitude: 2.2945)
        try store.save(items)
        check(try FavoritesStore(url: store.url).load() == items)
        try store.save([])
        check(try store.load().isEmpty)
        try Data("invalid json".utf8).write(to: store.url)
        do { _ = try store.load(); preconditionFailure("Corrupt data must report failure") }
        catch { check(try Data(contentsOf: store.url) == Data("invalid json".utf8)) }
        print("PASS: combined coordinates, validation, Unicode notes, save/reload/update/delete, corrupt-file preservation")
    }
}
