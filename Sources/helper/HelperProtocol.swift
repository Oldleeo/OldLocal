import Foundation

let oldLocalServiceName = "art.oldlee.oldlocal.helper"
let oldLocalPrivateBundle = "/Library/PrivilegedHelperTools/art.oldlee.oldlocal/OldLocal.app"
let oldLocalDaemonPlist = "/Library/LaunchDaemons/art.oldlee.oldlocal.helper.plist"

@objc(OldLocalService) protocol OldLocalService {
    func ping(withReply reply: @escaping (String) -> Void)
    func perform(_ command: String, latitude: Double, longitude: Double, withReply reply: @escaping (String) -> Void)
}

enum ServicePolicy {
    static func arguments(_ command: String, latitude: Double, longitude: Double) -> [String]? {
        if command == "reset" { return ["reset"] }
        guard command == "set", latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return ["set", "--latitude", String(latitude), "--longitude", String(longitude)]
    }
}
