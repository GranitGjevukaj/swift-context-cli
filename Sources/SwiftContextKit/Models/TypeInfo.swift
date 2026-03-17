import Foundation

public enum TypeKind: String, Codable, Sendable {
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case actor
}

public struct TypeInfo: Codable, Sendable {
    public let name: String
    public let kind: TypeKind
    public let accessLevel: String?
    public let conformances: [String]
    public let properties: [PropertyInfo]
    public let methods: [MethodInfo]
    public let navigationSignals: [String]
    public let filePath: String

    public init(
        name: String,
        kind: TypeKind,
        accessLevel: String?,
        conformances: [String],
        properties: [PropertyInfo] = [],
        methods: [MethodInfo] = [],
        navigationSignals: [String] = [],
        filePath: String
    ) {
        self.name = name
        self.kind = kind
        self.accessLevel = accessLevel
        self.conformances = conformances
        self.properties = properties
        self.methods = methods
        self.navigationSignals = navigationSignals
        self.filePath = filePath
    }
}
