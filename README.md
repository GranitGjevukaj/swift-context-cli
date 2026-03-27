# swiftcontext

`swiftcontext` is a Swift CLI that analyzes Swift/iOS projects and generates structured context for AI coding agents.

## What It Generates

Running analysis produces two artifacts at your chosen output path:

- `AGENTS.md` (human-readable, agent-friendly project context)
- `.swiftcontext.json` (machine-readable manifest)

## Current Capabilities (v0.6 foundation)

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
- v0.5 polish:
  - Parallel file analysis for large projects
  - Config file support via `.swiftcontext.yml` (global conventions + per-module overrides + analysis parallelism)
  - User-friendly diagnostics and typed error paths
  - Global `--verbose` and `--quiet` flags
- Tooling and distribution:
  - CLI subcommands: `analyze`, `graph`, `preview`, `export`
  - MCP server executable target: `swiftcontext-mcp` (stdio JSON-RPC with `initialize`, `tools/list`, `tools/call`)
  - MCP tools: `get_module_structure`, `get_navigation_graph`, `get_view_bindings`, `get_type_info`
  - Homebrew formula in `Formula/swiftcontext.rb`
  - macOS CI workflow (`.github/workflows/swift.yml`)
  - Release automation (`.github/workflows/release.yml`) for universal binary + GitHub release

## Install

### Build from source

```bash
swift build -c release
```

### Homebrew (build from source)

Prerequisite: Xcode 16 or newer command line tools are required because the formula builds the CLI from source.

```bash
brew tap granitgjevukaj/swift-context-cli https://github.com/GranitGjevukaj/swift-context-cli.git
brew install --HEAD granitgjevukaj/swift-context-cli/swiftcontext
```

## Build

```bash
swift build
```

## MCP Server

Start the MCP server over stdio:

```bash
swift run swiftcontext-mcp
```

Supported MCP methods:
- `initialize`
- `tools/list`
- `tools/call`

Available tools:
- `get_module_structure` (`projectPath?`, `moduleName?`)
- `get_navigation_graph` (`projectPath?`)
- `get_view_bindings` (`projectPath?`)
- `get_type_info` (`projectPath?`, `typeName`, `moduleName?`)

## Global Flags

All subcommands support:

- `--verbose`: print diagnostics and analysis progress
- `--quiet`: suppress non-error output
- `--config <path>`: load config from a custom `.swiftcontext.yml`

## Config File (`.swiftcontext.yml`)

Example:

```yaml
conventions:
  viewModelSuffix: ViewModel
  coordinatorSuffix: Coordinator
  testSuffix: Tests
  mockPrefix: Mock

analysis:
  parallelism: auto # or a positive integer (e.g. 8)

moduleOverrides:
  AppCore:
    viewModelSuffix: VM
```

Notes:
- If `--config` is not provided, `swiftcontext` looks for `.swiftcontext.yml` at the detected project root.
- Supported top-level sections are `conventions`, `moduleOverrides` (alias: `overrides`), and `analysis`.

## Commands

### Analyze

Generate `AGENTS.md` and/or `.swiftcontext.json`.

```bash
swift run swiftcontext analyze
swift run swiftcontext analyze --project /path/to/project --output /path/to/output --format both
swift run swiftcontext analyze --project /path/to/project --verbose
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
- Homebrew currently installs from the repository source rather than a prebuilt release tarball.
- SPM parsing currently assumes standard target layout and will be expanded to parse `Package.swift` target paths directly in a future version.
