# launcher_native

FFI bindings to the Rust native core + in-memory logging.

## Commands

| Command | What it does |
|---------|-------------|
| `dart analyze --fatal-infos` | Static analysis |
| `dart pub get` | Resolve dependencies |
| `cd ../../rust && cargo build --release` | Build the Rust library |
| `cd ../../rust && cargo test` | Test the Rust library |

## Key Exports

### NativeLib (singleton FFI wrapper)
- `NativeLib.instance` — singleton access
- `NativeLib.isAvailable` — check if dylib loaded
- Git: `getLastCommitDate()`, `getCommitCount()`, `hasUncommittedChanges()`, `getUnpushedCommitCount()`, `isGitRepository()`, `getMonthlyCommitCounts()`
- Health: `calculateHealthScore()`, `calculateHealthScoresBatch()`
- Stats: `calculateYearStats()`
- Scan: `scanForRepos(root, maxDepth)`

### AppLogger (in-memory ring buffer)
- `.debug()`, `.info()`, `.warn()`, `.error()` — log methods
- `.logs` — immutable list of LogEntry (max 500)
- `.forCategory(name)` / `.atLevel(minLevel)` — filtered views
- Listener pattern for real-time log subscriptions

## Patterns

- Singleton with lazy loading for NativeLib
- Try-multiple-paths strategy for loading dylib (macOS/Linux/Windows)
- String marshalling via `.toNativeUtf8()` + FFI memory management
- JSON round-tripping for complex Rust return values
- Ring buffer (500 entries max) for AppLogger

## Dependencies

- `ffi: ^2.1.0` (Dart FFI)
- Rust library at `rust/target/release/libproject_launcher_core.dylib`
