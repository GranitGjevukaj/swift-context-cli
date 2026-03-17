import Foundation
import Testing
@testable import SwiftContextKit

struct EmitterTests {
    @Test
    func emitsMarkdownAndJSON() throws {
        let manifest = ContextManifest(
            version: "0.4.0",
            project: ProjectOverview(
                name: "Demo",
                kind: "spm",
                rootPath: "/tmp/Demo",
                minimumDeploymentTarget: nil,
                generatedAt: "2026-03-17T00:00:00Z"
            ),
            modules: [
                ModuleInfo(
                    name: "Core",
                    sourceFileCount: 1,
                    imports: ["Foundation"],
                    types: [
                        TypeInfo(
                            name: "Thing",
                            kind: .struct,
                            accessLevel: "public",
                            conformances: ["Codable"],
                            properties: [
                                PropertyInfo(
                                    name: "value",
                                    typeName: "Int",
                                    accessLevel: "public",
                                    wrappers: []
                                )
                            ],
                            methods: [
                                MethodInfo(
                                    name: "load",
                                    parameters: [],
                                    returnType: "Int",
                                    isAsync: false,
                                    isThrowing: false,
                                    accessLevel: "public"
                                )
                            ],
                            filePath: "/tmp/Demo/Sources/Core/Thing.swift"
                        )
                    ]
                )
            ],
            viewBindings: [
                ViewBinding(
                    module: "Core",
                    viewType: "HomeView",
                    viewModelType: "HomeViewModel",
                    wrapper: "StateObject",
                    publishedProperties: ["title"]
                )
            ]
        )

        let markdown = MarkdownEmitter.emit(manifest: manifest)
        #expect(markdown.contains("# Project Context: Demo"))
        #expect(markdown.contains("### Core"))
        #expect(markdown.contains("## View ↔ ViewModel Bindings"))
        #expect(markdown.contains("## Architecture Patterns"))
        #expect(markdown.contains("## Test Coverage Surface"))
        #expect(markdown.contains("HomeView"))

        let json = try JSONEmitter.emit(manifest: manifest)
        #expect(json.contains("\"version\" : \"0.4.0\""))
        #expect(json.contains("\"name\" : \"Thing\""))
        #expect(json.contains("\"viewBindings\""))
        #expect(json.contains("\"patterns\""))
        #expect(json.contains("\"testCoverage\""))
    }
}
