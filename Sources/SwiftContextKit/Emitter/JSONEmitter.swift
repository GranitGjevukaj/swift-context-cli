import Foundation

public enum JSONEmitter {
    public static func emit(manifest: ContextManifest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "SwiftContextKit.JSONEmitter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode manifest as UTF-8"]
            )
        }
        return json + "\n"
    }
}
