import Foundation
import Darwin

@main
struct InstallerMain {
    static func run(_ executable: String, _ arguments: [String], allowFailure: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 && !allowFailure { throw SignatureFailure.invalid }
    }
    static func main() {
        guard geteuid() == 0, CommandLine.arguments.count == 3,
              let uid = UInt32(CommandLine.arguments[2]), uid >= 501 else { exit(1) }
        let operation = CommandLine.arguments[1]
        guard operation == "install" || operation == "uninstall" else { exit(1) }
        setgroups(0, nil); setgid(0); setuid(0)
        let fm = FileManager.default
        let folder = "/Library/PrivilegedHelperTools/art.oldlee.oldlocal"
        do {
            if operation == "uninstall" {
                try run("/bin/launchctl", ["bootout", "system/" + oldLocalServiceName], allowFailure: true)
                if fm.fileExists(atPath: oldLocalDaemonPlist) { try fm.removeItem(atPath: oldLocalDaemonPlist) }
                if fm.fileExists(atPath: folder) { try fm.removeItem(atPath: folder) }
                print("OLDLOCAL_HELPER_REMOVED"); return
            }
            var console = stat()
            guard stat("/dev/console", &console) == 0, console.st_uid == uid else { throw SignatureFailure.invalid }
            let app = URL(fileURLWithPath: "/Applications/OldLocal.app")
            let hash = try signingHash(at: app)
            var existing = stat()
            if lstat(folder, &existing) == 0 {
                guard existing.st_uid == 0, existing.st_mode & S_IFMT == S_IFDIR,
                      existing.st_mode & 0o022 == 0 else { throw SignatureFailure.invalid }
            } else {
                try fm.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755, .ownerAccountID: 0, .groupOwnerAccountID: 0])
            }
            let fresh = URL(fileURLWithPath: folder).appendingPathComponent("staging-" + UUID().uuidString + ".app")
            try fm.copyItem(at: app, to: fresh)
            try run("/bin/chmod", ["-RN", fresh.path])
            let enumerator = fm.enumerator(at: fresh, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey])!
            for case let item as URL in enumerator {
                let info = try item.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                guard info.isSymbolicLink != true else { throw SignatureFailure.invalid }
                try fm.setAttributes([.ownerAccountID: 0, .groupOwnerAccountID: 0, .posixPermissions: info.isDirectory == true ? 0o755 : 0o644], ofItemAtPath: item.path)
            }
            for relative in ["Contents/MacOS/MacLocation", "Contents/Library/HelperTools/OldLocalHelper", "Contents/Library/HelperTools/OldLocalInstaller", "Contents/Resources/backend/LocationPreferences"] {
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fresh.appendingPathComponent(relative).path)
            }
            try fm.setAttributes([.ownerAccountID: 0, .groupOwnerAccountID: 0, .posixPermissions: 0o755], ofItemAtPath: fresh.path)
            guard try signingHash(at: fresh) == hash else { throw SignatureFailure.invalid }
            try run("/bin/launchctl", ["bootout", "system/" + oldLocalServiceName], allowFailure: true)
            let destination = URL(fileURLWithPath: oldLocalPrivateBundle)
            let previous = URL(fileURLWithPath: folder).appendingPathComponent("previous-" + UUID().uuidString + ".app")
            let previousPlist = fm.fileExists(atPath: oldLocalDaemonPlist) ? try Data(contentsOf: URL(fileURLWithPath: oldLocalDaemonPlist)) : nil
            if fm.fileExists(atPath: destination.path) { try fm.moveItem(at: destination, to: previous) }
            do {
                try fm.moveItem(at: fresh, to: destination)
                let helper = destination.appendingPathComponent("Contents/Library/HelperTools/OldLocalHelper").path
                let plist: [String: Any] = ["Label": oldLocalServiceName, "ProgramArguments": [helper, String(uid), hash],
                    "MachServices": [oldLocalServiceName: true], "AssociatedBundleIdentifiers": ["art.oldlee.maclocation"],
                    "RunAtLoad": false, "KeepAlive": false, "ProcessType": "Interactive", "ThrottleInterval": 10]
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: URL(fileURLWithPath: oldLocalDaemonPlist), options: .atomic)
                try fm.setAttributes([.ownerAccountID: 0, .groupOwnerAccountID: 0, .posixPermissions: 0o644], ofItemAtPath: oldLocalDaemonPlist)
                try run("/bin/chmod", ["-N", oldLocalDaemonPlist])
                try run("/bin/launchctl", ["bootstrap", "system", oldLocalDaemonPlist])
                print("OLDLOCAL_HELPER_INSTALLED")
            } catch {
                if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
                if fm.fileExists(atPath: previous.path) { try? fm.moveItem(at: previous, to: destination) }
                if let data = previousPlist {
                    try? data.write(to: URL(fileURLWithPath: oldLocalDaemonPlist), options: .atomic)
                    try? run("/bin/launchctl", ["bootstrap", "system", oldLocalDaemonPlist])
                } else if fm.fileExists(atPath: oldLocalDaemonPlist) { try? fm.removeItem(atPath: oldLocalDaemonPlist) }
                throw error
            }
        } catch {
            FileHandle.standardError.write(Data("定位组件安装未完成；原定位备份与收藏保留。\n".utf8))
            exit(1)
        }
    }
}
