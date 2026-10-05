import Foundation
import CoreFoundation

enum PreferenceFailure: Error { case sync, type, number }

struct PreferenceAccess {
    let domain: String

    func read(_ key: String) throws -> Double? {
        guard CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else {
            throw PreferenceFailure.sync
        }
        guard let stored = CFPreferencesCopyValue(key as CFString, domain as CFString,
                                                 kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else { return nil }
        guard CFGetTypeID(stored) == CFNumberGetTypeID() else { throw PreferenceFailure.type }
        let number = unsafeBitCast(stored, to: CFNumber.self)
        var value: Double = 0
        guard CFNumberGetValue(number, .doubleType, &value), value.isFinite else { throw PreferenceFailure.number }
        return value
    }

    func write(_ key: String, value: Double?) throws {
        var stored: CFNumber?
        if var value = value {
            guard value.isFinite else { throw PreferenceFailure.number }
            stored = CFNumberCreate(nil, .doubleType, &value)
            guard stored != nil else { throw PreferenceFailure.number }
        }
        CFPreferencesSetValue(key as CFString, stored, domain as CFString,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        guard CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else {
            throw PreferenceFailure.sync
        }
    }
}
