import Foundation
import Darwin

final class ReplyOnce {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
}

final class HelperClient {
    private var connection: NSXPCConnection?
    func invalidate() { connection?.invalidate(); connection = nil }
    func check(completion: @escaping (Bool) -> Void) {
        invalidate()
        do {
            let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/HelperTools/OldLocalHelper")
            _ = try signingHash(at: Bundle.main.bundleURL)
            let hash = try signingHash(at: helper)
            let connection = NSXPCConnection(machServiceName: oldLocalServiceName, options: .privileged)
            connection.setCodeSigningRequirement("cdhash H\"\(hash)\"")
            connection.remoteObjectInterface = NSXPCInterface(with: OldLocalService.self)
            self.connection = connection
            connection.resume()
            let once = ReplyOnce()
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                guard once.claim() else { return }
                DispatchQueue.main.async { completion(false) }
            } as? OldLocalService
            guard let proxy = proxy else { invalidate(); completion(false); return }
            proxy.ping { value in
                guard once.claim() else { return }
                let trusted = value == "OldLocalHelper/2.1" && connection.effectiveUserIdentifier == 0
                DispatchQueue.main.async { completion(trusted) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                guard once.claim() else { return }
                connection.invalidate()
                completion(false)
            }
        } catch { completion(false) }
    }
    func perform(_ command: String, latitude: Double, longitude: Double, completion: @escaping (String) -> Void) {
        guard let connection = connection else { completion("RESULT_JSON {\"status\":\"helper_unavailable\"}"); return }
        let once = ReplyOnce()
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
            guard once.claim() else { return }
            DispatchQueue.main.async { completion("RESULT_JSON {\"status\":\"helper_unavailable\"}") }
        } as? OldLocalService
        guard let proxy = proxy else { completion("RESULT_JSON {\"status\":\"helper_unavailable\"}"); return }
        proxy.perform(command, latitude: latitude, longitude: longitude) { output in
            guard once.claim() else { return }
            DispatchQueue.main.async { completion(output) }
        }
    }
}
