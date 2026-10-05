import Foundation

enum GroupFailure: Error { case reserved, empty, duplicate }
struct GroupOperations {
    static func name(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw GroupFailure.empty }
        guard value != "全部分组", value != "未分组" else { throw GroupFailure.reserved }
        return value
    }
    static func rename(_ source: String, to target: String, in items: [Favorite]) -> [Favorite] {
        items.map { item in
            var copy = item
            if copy.group == source { copy.group = target }
            return copy
        }
    }
    static func remove(_ source: String, from items: [Favorite]) -> [Favorite] { rename(source, to: "未分组", in: items) }
}
