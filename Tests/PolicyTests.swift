import Foundation
import Security

@main
struct PolicyTests {
    static func main() {
        precondition(ServicePolicy.arguments("set", latitude: 3.179221, longitude: 101.703963) == ["set", "--latitude", "3.179221", "--longitude", "101.703963"])
        for (lat, lon) in [(Double.nan, 0.0), (0.0, Double.infinity), (91.0, 0.0), (0.0, 181.0)] {
            precondition(ServicePolicy.arguments("set", latitude: lat, longitude: lon) == nil)
        }
        for command in ["shell", "set;id", "exec", "write", "uninstall", ""] {
            precondition(ServicePolicy.arguments(command, latitude: 0, longitude: 0) == nil)
        }
        precondition(ServicePolicy.arguments("reset", latitude: 0, longitude: 0) == ["reset"])
        var requirement: SecRequirement?
        precondition(SecRequirementCreateWithString("identifier \"art.oldlee.maclocation\" and cdhash H\"0123456789012345678901234567890123456789\"" as CFString,
                                                  SecCSFlags(rawValue: 0), &requirement) == errSecSuccess)
        print("PASS: finite coordinate bounds, strict command whitelist, code-signature requirement syntax")
    }
}
