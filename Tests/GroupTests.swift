import Foundation

@main
struct GroupTests {
    static func main() throws {
        let first = Favorite(id: UUID(), note: "原备注", coordinates: Coordinates(latitude: 3.179032, longitude: 101.703557), group: "旅行")
        let second = Favorite(id: UUID(), note: "其他收藏", coordinates: Coordinates(latitude: 1, longitude: 2), group: "工作")
        let values = [first, second]
        let renamed = GroupOperations.rename("旅行", to: "出行", in: values)
        precondition(renamed[0].group == "出行" && renamed[0].id == first.id && renamed[0].note == first.note && renamed[0].coordinates == first.coordinates)
        precondition(renamed[1] == second)
        let removed = GroupOperations.remove("旅行", from: values)
        precondition(removed[0].group == "未分组" && removed.count == values.count && removed[0].id == first.id && removed[0].coordinates == first.coordinates)
        precondition(removed[1] == second)
        for name in ["", "   ", "未分组", "全部分组"] {
            do { _ = try GroupOperations.name(name); preconditionFailure("Reserved name accepted") } catch {}
        }
        let trimmed = try GroupOperations.name("  新名称  ")
        precondition(trimmed == "新名称")
        print("PASS: group rename/delete preserve IDs, notes, coordinates and unrelated favorites; reserved names rejected")
    }
}
