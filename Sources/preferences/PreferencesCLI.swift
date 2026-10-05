import Foundation
import Darwin

@main
struct PreferencesCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let domains = ["com.apple.locationd", "com.apple.locationd.notbackedup"]
        let keys = ["SimulatedLocationLatitude", "SimulatedLocationLongitude", "SimulatedLocationAccuracy"]
        guard let account = getpwnam("_locationd"), geteuid() == account.pointee.pw_uid,
              arguments.count >= 3, domains.contains(arguments[1]), keys.contains(arguments[2]) else {
            fail("定位参数访问身份或范围不符。")
        }
        let operation = arguments[0]
        let access = PreferenceAccess(domain: arguments[1])
        do {
            switch operation {
            case "read" where arguments.count == 3:
                let value = try access.read(arguments[2])
                let data = try JSONSerialization.data(withJSONObject: ["value": value.map { $0 as Any } ?? NSNull()])
                print(String(decoding: data, as: UTF8.self))
            case "write" where arguments.count == 4:
                guard let value = Double(arguments[3]), value.isFinite else { fail("定位参数数值无效。") }
                try access.write(arguments[2], value: value)
            case "delete" where arguments.count == 3:
                try access.write(arguments[2], value: nil)
            default: fail("定位参数操作无效。")
            }
        } catch PreferenceFailure.type { fail("定位模拟参数类型异常，未视为缺失。") }
        catch PreferenceFailure.number { fail("定位模拟参数数值异常。") }
        catch { fail("定位参数同步失败，未假定操作成功。") }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
