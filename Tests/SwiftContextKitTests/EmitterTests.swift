import Foundation
import Testing
@testable import SwiftContextKit

struct EmitterTests {
    @Test
    func emitsMarkdownAndJSON() throws {
        let manifest = ContextManifest(
            version: "0.1.0",
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
                            filePath: "/tmp/Demo/Sources/Core/Thing.swift"
                        )
                    ]
                )
            ]
        )

        let markdown = MarkdownEmitter.emit(manifest: manifest)
        #expect(markdown.contains("# Project Context: Demo"))
        #expect(markdown.contains("### Core"))

        let json = try JSONEmitter.emit(manifest: manifest)
        #expect(json.contains("\"version\" : \"0.1.0\""))
        #expect(json.contains("\"name\" : \"Thing\""))
    }
}
