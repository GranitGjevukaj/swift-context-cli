# swiftcontext

`swiftcontext` is a Swift CLI that analyzes Swift projects and generates AI-agent context files.

## Build

```bash
swift build
```

## Usage

```bash
swift run swiftcontext analyze
swift run swiftcontext analyze --project /path/to/project --output /path/to/output --format both
```

This generates:
- `AGENTS.md`
- `.swiftcontext.json`
