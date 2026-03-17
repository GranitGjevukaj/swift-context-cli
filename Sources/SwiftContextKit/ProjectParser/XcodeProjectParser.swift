import Foundation
import XcodeProj

public enum XcodeProjectParser {
    public static func parse(projectFile: URL) throws -> ProjectModel {
        let root = projectFile.deletingLastPathComponent()
        let projectName = projectFile.deletingPathExtension().lastPathComponent
        let xcodeProj: XcodeProj
        do {
            xcodeProj = try XcodeProj(pathString: projectFile.path)
        } catch {
            throw SwiftContextError.fileReadFailed(path: projectFile.path, underlying: error)
        }
        let pbxproj = xcodeProj.pbxproj

        let sourceRoot = root.path
        let targets: [ProjectTarget] = try pbxproj.nativeTargets
            .sorted(by: { $0.name < $1.name })
            .map { target in
                let sourceFiles = try sourceFiles(for: target, sourceRoot: sourceRoot)
                return ProjectTarget(name: target.name, sourceFiles: sourceFiles)
            }

        let deploymentTarget = detectMinimumDeploymentTarget(from: pbxproj)

        return ProjectModel(
            name: projectName,
            kind: .xcodeproj,
            rootPath: root.path,
            minimumDeploymentTarget: deploymentTarget,
            targets: targets
        )
    }

    private static func sourceFiles(for target: PBXNativeTarget, sourceRoot: String) throws -> [String] {
        var files: Set<String> = []

        // Classic target membership through PBXSourcesBuildPhase build files.
        for file in try target.sourceFiles() {
            guard let fileReference = file as? PBXFileReference else {
                continue
            }
            guard let fullPath = try fileReference.fullPath(sourceRoot: sourceRoot) else {
                continue
            }
            guard fullPath.hasSuffix(".swift") else { continue }
            files.insert(URL(fileURLWithPath: fullPath).standardizedFileURL.path)
        }

        // Xcode 16+ may use file-system synchronized groups where source files are
        // implied by directory structure instead of explicit build file entries.
        for synchronizedGroup in target.fileSystemSynchronizedGroups ?? [] {
            guard let groupRoot = try synchronizedGroup.fullPath(sourceRoot: sourceRoot) else {
                continue
            }
            let membershipExceptions = synchronizedMembershipExceptions(
                for: target,
                synchronizedGroup: synchronizedGroup
            )
            files.formUnion(
                collectSwiftFiles(
                    in: groupRoot,
                    excludingRelativePaths: membershipExceptions
                )
            )
        }

        return files.sorted()
    }

    private static func synchronizedMembershipExceptions(
        for target: PBXNativeTarget,
        synchronizedGroup: PBXFileSystemSynchronizedRootGroup
    ) -> Set<String> {
        var exceptions: Set<String> = []
        for exception in synchronizedGroup.exceptions ?? [] {
            if let buildException = exception as? PBXFileSystemSynchronizedBuildFileExceptionSet,
               buildException.target === target {
                for path in buildException.membershipExceptions ?? [] {
                    exceptions.insert(normalizeRelativePath(path))
                }
                continue
            }

            if let phaseException = exception as? PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet,
               phaseException.buildPhase.buildPhase == .sources,
               target.buildPhases.contains(where: { $0 === phaseException.buildPhase }) {
                for path in phaseException.membershipExceptions ?? [] {
                    exceptions.insert(normalizeRelativePath(path))
                }
            }
        }
        return exceptions
    }

    private static func collectSwiftFiles(in rootPath: String, excludingRelativePaths: Set<String>) -> Set<String> {
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var files: Set<String> = []
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let relativePath = normalizeRelativePath(
                String(fileURL.path.dropFirst(rootURL.path.count + 1))
            )

            if isExcluded(relativePath: relativePath, exclusions: excludingRelativePaths) {
                continue
            }
            files.insert(fileURL.standardizedFileURL.path)
        }
        return files
    }

    private static func isExcluded(relativePath: String, exclusions: Set<String>) -> Bool {
        for exclusion in exclusions where !exclusion.isEmpty {
            if relativePath == exclusion || relativePath.hasPrefix(exclusion + "/") {
                return true
            }
        }
        return false
    }

    private static func normalizeRelativePath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func detectMinimumDeploymentTarget(from pbxproj: PBXProj) -> String? {
        var deploymentTargets: [String] = []
        for config in pbxproj.buildConfigurations {
            let keys = ["IPHONEOS_DEPLOYMENT_TARGET", "MACOSX_DEPLOYMENT_TARGET", "TVOS_DEPLOYMENT_TARGET", "WATCHOS_DEPLOYMENT_TARGET"]
            for key in keys {
                if let value = config.buildSettings[key] as? String, !value.isEmpty {
                    deploymentTargets.append(value)
                }
            }
        }
        return deploymentTargets.sorted().first
    }
}
