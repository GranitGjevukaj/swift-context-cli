import Foundation

public struct CoordinatorInfo: Codable, Sendable {
    public let module: String
    public let name: String
    public let heuristics: [String]
    public let childCoordinators: [String]

    public init(module: String, name: String, heuristics: [String], childCoordinators: [String]) {
        self.module = module
        self.name = name
        self.heuristics = heuristics
        self.childCoordinators = childCoordinators
    }
}

public struct NavigationEdge: Codable, Sendable {
    public let module: String
    public let from: String
    public let to: String
    public let relation: String

    public init(module: String, from: String, to: String, relation: String) {
        self.module = module
        self.from = from
        self.to = to
        self.relation = relation
    }
}

public struct ViewNavigationSurface: Codable, Sendable {
    public let module: String
    public let viewType: String
    public let apis: [String]

    public init(module: String, viewType: String, apis: [String]) {
        self.module = module
        self.viewType = viewType
        self.apis = apis
    }
}

public struct NavigationGraph: Codable, Sendable {
    public let coordinators: [CoordinatorInfo]
    public let edges: [NavigationEdge]
    public let viewSurfaces: [ViewNavigationSurface]

    public init(coordinators: [CoordinatorInfo], edges: [NavigationEdge], viewSurfaces: [ViewNavigationSurface]) {
        self.coordinators = coordinators
        self.edges = edges
        self.viewSurfaces = viewSurfaces
    }

    public static let empty = NavigationGraph(coordinators: [], edges: [], viewSurfaces: [])
}

public struct DependencyEdge: Codable, Sendable {
    public let module: String
    public let protocolType: String
    public let concreteType: String

    public init(module: String, protocolType: String, concreteType: String) {
        self.module = module
        self.protocolType = protocolType
        self.concreteType = concreteType
    }
}

public struct DependencyGraph: Codable, Sendable {
    public let edges: [DependencyEdge]

    public init(edges: [DependencyEdge]) {
        self.edges = edges
    }

    public static let empty = DependencyGraph(edges: [])
}
