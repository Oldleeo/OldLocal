import Foundation
import Security

enum SignatureFailure: Error { case invalid }
func signingHash(at url: URL) throws -> String {
    var code: SecStaticCode?
    guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(rawValue: 0), &code) == errSecSuccess,
          let code = code,
          SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: 0), nil) == errSecSuccess else { throw SignatureFailure.invalid }
    var info: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
          let data = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else { throw SignatureFailure.invalid }
    return data.map { String(format: "%02x", $0) }.joined()
}
