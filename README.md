# ContextFabricKit

A Swift Package that bridges the [Context Fabric](https://context-fabric.ai/docs) Python library to Swift. It embeds a signed Python 3.13 interpreter (via [BeeWare Python-Apple-support](https://github.com/beeware/python-apple-support)) so macOS apps can run `cfabric` corpus queries natively — including App Store distribution.

## Requirements

- macOS 13+
- Xcode 16+
- Python 3.13 on PATH (e.g. `brew install python@3.13`) — used only during bootstrap to pip-install `context-fabric` into the embedded interpreter

## Bootstrap

The embedded `Python.xcframework` must be built before `swift build` will succeed. Run once per machine:

```bash
make bootstrap
```

This chains four steps:
1. Downloads the BeeWare Python 3.13 archive
2. Extracts `Python.xcframework` (the stdlib lives inside it)
3. Installs `context-fabric` (+ `numpy`, `pyyaml`) into the embedded `site-packages`
4. Re-signs all `.so` extension modules and the framework (ad-hoc by default)

For App Store or notarization builds, pass your certificate identity:

```bash
make bootstrap SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
```

## Usage

```swift
import ContextFabricKit

// Initialize the embedded Python runtime once, before any cfabric calls.
// In an app this is automatic; in tests supply an explicit path.
PythonRuntime.initialize()

// Load a corpus and query it.
let fabric = Fabric(path: "/path/to/corpus")
let results = fabric.search("word")
for node in results {
    print(fabric.text(for: node))
}
```

`Fabric.init(path:)` calls `PythonRuntime.initialize()` automatically, so explicit initialization is only needed when you want to bootstrap Python earlier or supply a custom `pythonHome:`.

## Adding to an App

1. Add this package as a dependency in Xcode or `Package.swift`.
2. In your app target's **Frameworks, Libraries, and Embedded Content**, add `Python.xcframework` (from `Artifacts/`) and set it to **Do Not Embed** — Xcode embeds it automatically when it comes from an SPM binary target.
3. Add a **Run Script** Build Phase to re-sign the copied framework:

```bash
find "$CODESIGNING_FOLDER_PATH/Contents/Frameworks/Python.framework" \
    -name "*.so" -exec /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" {} \;
/usr/bin/codesign --force --deep --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
    "$CODESIGNING_FOLDER_PATH/Contents/Frameworks/Python.framework"
```

## Building & Testing

```bash
swift build
swift test
swift test --filter ContextFabricKitTests.<TestName>
```

## License

MIT
