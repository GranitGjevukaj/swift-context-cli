import Foundation

public struct ModuleInfo: Codable, Sendable {
    public let name: String
    public let sourceFileCount: Int
    public let imports: [String]
    public let types: [TypeInfo]

    public init(name: String, sourceFileCount: Int, imports: [String], types: [TypeInfo]) {
        self.name = name
        self.sourceFileCount = sourceFileCount
        self.imports = imports
        self.types = types
    }
}
