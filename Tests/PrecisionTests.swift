import Foundation
import CoreFoundation

@main
struct PrecisionTests {
    static let values = [3.179221, 101.703963, 48.8584, 2.2945, -179.123456789123, 10.0]
    static func check(_ passed: Bool) { precondition(passed) }
    static func main() throws {
        if CommandLine.arguments.count == 2 {
            let access = PreferenceAccess(domain: CommandLine.arguments[1])
            for (index, value) in values.enumerated() { check(try access.read("value\(index)") == value) }
            return
        }
        let domain = "art.oldlee.maclocation.precision-test." + UUID().uuidString
        let access = PreferenceAccess(domain: domain)
        for (index, value) in values.enumerated() {
            try access.write("value\(index)", value: value)
            check(try access.read("value\(index)") == value)
        }
        let verifier = Process()
        verifier.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        verifier.arguments = [domain]
        try verifier.run()
        verifier.waitUntilExit()
        precondition(verifier.terminationStatus == 0)
        let key = "invalid" as CFString
        CFPreferencesSetValue(key, "not a number" as CFString, domain as CFString,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        precondition(CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost))
        do { _ = try access.read("invalid"); preconditionFailure("Invalid type accepted") }
        catch PreferenceFailure.type {}
        for index in values.indices { try access.write("value\(index)", value: nil) }
        try access.write("invalid", value: nil)
        check(try access.read("value0") == nil)
        print("PASS: full Double precision across processes, invalid-type rejection, absent-key handling")
    }
}
