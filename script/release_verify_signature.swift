import CryptoKit
import Foundation

// The public key comes from the exported app, independently of sign_update's key.
guard CommandLine.arguments.count == 4,
      let signature = Data(base64Encoded: CommandLine.arguments[2]),
      let key = Data(base64Encoded: CommandLine.arguments[3]),
      signature.count == 64, key.count == 32 else {
    fputs("Invalid public key or Ed25519 signature.\n", stderr)
    exit(1)
}
do {
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: key)
    let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    guard publicKey.isValidSignature(signature, for: archive) else {
        fputs("Update signature does not match the public key embedded in the app.\n", stderr)
        exit(1)
    }
} catch {
    fputs("Could not verify the update signature.\n", stderr)
    exit(1)
}
