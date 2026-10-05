import Foundation
import Darwin

final class HelperDelegate: NSObject, NSXPCListenerDelegate, OldLocalService {
    private let allowedUID: uid_t
    private let clientHash: String
    private let gate = DispatchSemaphore(value: 1)
    private let worker = DispatchQueue(label: "art.oldlee.oldlocal.helper.work")
    init(uid: uid_t, hash: String) { allowedUID = uid; clientHash = hash; super.init() }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        var console = stat()
        guard stat("/dev/console", &console) == 0,
              connection.effectiveUserIdentifier == allowedUID, console.st_uid == allowedUID else { return false }
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(connection.processIdentifier, &path, UInt32(path.count)) > 0,
              String(cString: path) == "/Applications/OldLocal.app/Contents/MacOS/MacLocation" else { return false }
        connection.setCodeSigningRequirement("identifier \"art.oldlee.maclocation\" and cdhash H\"\(clientHash)\"")
        connection.exportedInterface = NSXPCInterface(with: OldLocalService.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }
    func ping(withReply reply: @escaping (String) -> Void) { reply("OldLocalHelper/2.1") }
    func perform(_ command: String, latitude: Double, longitude: Double, withReply reply: @escaping (String) -> Void) {
        var console = stat()
        guard stat("/dev/console", &console) == 0, console.st_uid == allowedUID else {
            reply("RESULT_JSON {\"status\":\"session_not_active\"}"); return
        }
        guard let arguments = ServicePolicy.arguments(command, latitude: latitude, longitude: longitude) else {
            reply("RESULT_JSON {\"status\":\"invalid_request\"}"); return
        }
        guard gate.wait(timeout: .now()) == .success else { reply("RESULT_JSON {\"status\":\"busy\"}"); return }
        worker.async {
            defer { self.gate.signal() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-I", "-B", oldLocalPrivateBundle + "/Contents/Resources/backend/app_backend.py"] + arguments
            process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": "/var/root", "LANG": "en_US.UTF-8"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let output = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                reply(String(decoding: output.prefix(65536), as: UTF8.self))
            } catch { reply("RESULT_JSON {\"status\":\"helper_execution_failed\"}") }
        }
    }
}

@main
struct HelperMain {
    static func main() {
        guard getuid() == 0, geteuid() == 0, CommandLine.arguments.count == 3,
              let uid = UInt32(CommandLine.arguments[1]), uid >= 501,
              CommandLine.arguments[2].count == 40,
              CommandLine.arguments[2].allSatisfy({ $0.isHexDigit }) else { exit(1) }
        let delegate = HelperDelegate(uid: uid, hash: CommandLine.arguments[2])
        let listener = NSXPCListener(machServiceName: oldLocalServiceName)
        listener.delegate = delegate
        listener.resume()
        withExtendedLifetime(delegate) { RunLoop.current.run() }
    }
}
