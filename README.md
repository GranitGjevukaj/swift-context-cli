# swiftcontext

`swiftcontext` is a Swift CLI that analyzes Swift/iOS projects and generates structured context for AI coding agents.

## What It Generates

Running analysis produces two artifacts at your chosen output path:

- `AGENTS.md` (human-readable, agent-friendly project context)
- `.swiftcontext.json` (machine-readable manifest)

## Current Capabilities (v0.4)

- Project parsing:
  - Xcode projects (`.xcodeproj`) via `XcodeProj`
  - Swift packages via conventional `Sources/` + `Tests/` layout
- Syntax analysis via `SwiftSyntax`:
  - Types, conformances, access levels
  - Property wrappers (`@Published`, `@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, `@Binding`, `@Environment`)
  - Method signatures (params, return type, `async`/`throws`)
- Graphs:
  - View ↔ ViewModel bindings
  - Navigation signals (`NavigationStack`, `NavigationPath`, `sheet`, `fullScreenCover`)
  - Dependency graph (protocol → concrete mappings)
- Pattern and convention inference:
  - MVVM, MVVM-C, TCA signals
  - Naming conventions and file organization hints
  - Test coverage surface (tested vs untested type detection)
- Export and tooling commands:
  - `analyze`, `graph`, `preview`, `export`

## Build

```bash
swift build
```

## Commands

### Analyze

Generate `AGENTS.md` and/or `.swiftcontext.json`.

```bash
swift run swiftcontext analyze
swift run swiftcontext analyze --project /path/to/project --output /path/to/output --format both
```

`--format` options:
- `markdown`
- `json`
- `both` (default)

### Graph

Generate graph output for navigation, dependency, or bindings.

```bash
swift run swiftcontext graph --project /path/to/project --type navigation --format json
swift run swiftcontext graph --project /path/to/project --type dependency --format mermaid
swift run swiftcontext graph --project /path/to/project --type binding --format mermaid
```

`--type` options:
- `navigation`
- `dependency`
- `binding`

`--format` options:
- `json`
- `mermaid`

### Preview

Preview analysis for a single module.

```bash
swift run swiftcontext preview AppCore --project /path/to/project --format markdown
swift run swiftcontext preview AppCore --project /path/to/project --format json
```

`--format` options:
- `markdown` (default)
- `json`

### Export

Export context for different agent ecosystems.

```bash
swift run swiftcontext export --project /path/to/project --format agents-md
swift run swiftcontext export --project /path/to/project --format claude-md
swift run swiftcontext export --project /path/to/project --format cursorrules
```

You can optionally write export output to a file:

```bash
swift run swiftcontext export --project /path/to/project --format claude-md --output /tmp/CLAUDE.md
```

`--format` options:
- `agents-md`
- `claude-md`
- `cursorrules`

## Test

```bash
swift test
```

## Notes

- `AGENTS.md` is generated output and should not be hand-edited.
- SPM parsing currently assumes standard target layout and will be expanded to parse `Package.swift` target paths directly in a future version.
