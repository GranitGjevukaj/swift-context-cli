import Foundation

public enum ViewBindingGraphBuilder {
    private static let bindingWrappers = Set(["StateObject", "ObservedObject", "EnvironmentObject"])

    public static func build(modules: [ModuleInfo]) -> [ViewBinding] {
        var bindings: [ViewBinding] = []

        for module in modules {
            var typeLookup: [String: TypeInfo] = [:]
            var viewModelsByName: [String: TypeInfo] = [:]
            for type in module.types {
                if typeLookup[type.name] == nil {
                    typeLookup[type.name] = type
                }
                if isViewModel(type), viewModelsByName[type.name] == nil {
                    viewModelsByName[type.name] = type
                }
            }

            let views = module.types.filter { isView($0) }
            for view in views {
                for property in view.properties {
                    guard let wrapper = property.wrappers.first(where: { bindingWrappers.contains($0) }) else {
                        continue
                    }
                    guard let rawTypeName = property.typeName else {
                        continue
                    }

                    let normalizedTypeName = normalizeTypeName(rawTypeName)
                    guard let viewModel = viewModelsByName[normalizedTypeName] ?? typeLookup[normalizedTypeName], isViewModel(viewModel) else {
                        continue
                    }

                    let publishedProperties = viewModel.properties
                        .filter { $0.wrappers.contains("Published") }
                        .map(\.name)
                        .sorted()

                    bindings.append(
                        ViewBinding(
                            module: module.name,
                            viewType: view.name,
                            viewModelType: viewModel.name,
                            wrapper: wrapper,
                            publishedProperties: publishedProperties
                        )
                    )
                }
            }
        }

        return bindings
            .sorted {
                if $0.module != $1.module { return $0.module < $1.module }
                if $0.viewType != $1.viewType { return $0.viewType < $1.viewType }
                if $0.viewModelType != $1.viewModelType { return $0.viewModelType < $1.viewModelType }
                return $0.wrapper < $1.wrapper
            }
    }

    private static func isView(_ type: TypeInfo) -> Bool {
        type.conformances.contains("View") || type.name.hasSuffix("View")
    }

    private static func isViewModel(_ type: TypeInfo) -> Bool {
        type.conformances.contains("ObservableObject") ||
            type.name.hasSuffix("ViewModel") ||
            type.name.hasSuffix("VM")
    }

    private static func normalizeTypeName(_ raw: String) -> String {
        var typeName = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while typeName.hasSuffix("?") || typeName.hasSuffix("!") {
            typeName.removeLast()
        }

        if typeName.hasPrefix("some ") {
            typeName = String(typeName.dropFirst(5))
        }
        if typeName.hasPrefix("any ") {
            typeName = String(typeName.dropFirst(4))
        }

        if let genericStart = typeName.firstIndex(of: "<") {
            typeName = String(typeName[..<genericStart])
        }

        if let last = typeName.split(separator: ".").last {
            typeName = String(last)
        }
        return typeName
    }
}
