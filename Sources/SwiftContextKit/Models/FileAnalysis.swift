import Foundation

public struct FileAnalysis: Sendable {
    public let path: String
    public let imports: [String]
    public let types: [TypeInfo]

    public init(path: String, imports: [String], types: [TypeInfo]) {
        self.path = path
        self.imports = imports
        self.types = types
    }
}
