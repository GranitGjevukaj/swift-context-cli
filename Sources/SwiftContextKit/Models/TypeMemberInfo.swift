import Foundation

public struct PropertyInfo: Codable, Sendable {
    public let name: String
    public let typeName: String?
    public let accessLevel: String?
    public let wrappers: [String]

    public init(name: String, typeName: String?, accessLevel: String?, wrappers: [String]) {
        self.name = name
        self.typeName = typeName
        self.accessLevel = accessLevel
        self.wrappers = wrappers
    }
}

public struct MethodParameterInfo: Codable, Sendable {
    public let externalName: String?
    public let localName: String
    public let typeName: String

    public init(externalName: String?, localName: String, typeName: String) {
        self.externalName = externalName
        self.localName = localName
        self.typeName = typeName
    }
}

public struct MethodInfo: Codable, Sendable {
    public let name: String
    public let parameters: [MethodParameterInfo]
    public let returnType: String?
    public let isAsync: Bool
    public let isThrowing: Bool
    public let accessLevel: String?

    public init(
        name: String,
        parameters: [MethodParameterInfo],
        returnType: String?,
        isAsync: Bool,
        isThrowing: Bool,
        accessLevel: String?
    ) {
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrowing = isThrowing
        self.accessLevel = accessLevel
    }
}
