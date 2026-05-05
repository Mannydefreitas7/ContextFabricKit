# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

ContextFabricKit is a Swift Package that bridges the [Context Fabric](https://context-fabric.ai/docs) Python library (`cfabric`) to Swift. It embeds a signed Python 3.13 interpreter as an XCFramework so consumers can use Context Fabric corpus queries natively in macOS apps — including App Store distribution.

## One-Time Bootstrap (Makefile)

`Artifacts/Python.xcframework` must exist before `swift build` will succeed. Run once per machine:

```bash
make bootstrap                # full setup: download → extract → install-cfabric → sign
make bootstrap SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"  # for App Store signing
```

Individual targets (all idempotent):

```bash
make download-python          # fetch BeeWare Python-Apple-support archive
make extract                  # unpack Python.xcframework (stdlib lives inside it)
make install-cfabric          # pip-install context-fabric into embedded site-packages
make sign-python              # re-sign .so libs and Python.framework
```

`SIGN_IDENTITY` defaults to `-` (ad-hoc), which is sufficient for local development and testing. For notarization or App Store submission set it to your full certificate CN — `codesign --sign` does not accept a bare Team ID.

## Building & Testing

```bash
swift build
swift test
swift test --filter ContextFabricKitTests.<TestName>
```

Tests that call `PythonRuntime.initialize()` require `make bootstrap` to have been run. Pass an explicit `pythonHome:` path for tests running outside an app bundle:

```swift
PythonRuntime.initialize(pythonHome: "/path/to/Python.framework/Versions/3.13")
```

## Architecture

### BeeWare Python-Apple-support layout (3.13-b13+)

As of build b8+, the standard library is bundled **inside** the XCFramework — there is no separate `python-stdlib` directory to stage. The relevant paths within `Artifacts/Python.xcframework` are:

```
macos-arm64_x86_64/Python.framework/Versions/3.13/
├── Python                  (universal dylib)
├── include/python3.13/
└── lib/python3.13/
    ├── lib-dynload/        ← .so extension modules (must be signed)
    └── site-packages/      ← cfabric, numpy, pyyaml installed here by make install-cfabric
```

`PYTHONHOME` must point to `Versions/3.13/`; `PYTHONPATH` adds `lib/python3.13`, `lib-dynload`, and `site-packages`.

### Python version constraint

`context-fabric` (PyPI package name; imported as `cfabric`) requires Python **≥ 3.13**. The Makefile defaults `PYTHON_VERSION=3.13` and `BEEWARE_BUILD=b13`. Do not downgrade — 3.12 will fail at `make install-cfabric`.

### cfabric dependencies

`make install-cfabric` pulls in `context-fabric`, `numpy`, and `pyyaml` into the embedded site-packages. All are pure-Python or provide macOS arm64/x86_64 wheels, so no cross-compilation is needed.

### Swift↔Python bridge (PythonKit 0.5.1)

`Python` is declared as a `.binaryTarget` pointing to `Artifacts/Python.xcframework`. PythonKit (resolved at 0.5.1) links against it. `PythonRuntime.initialize()` sets `PYTHONHOME`/`PYTHONPATH` before PythonKit's lazy `Py_Initialize()` fires — it must be called before any `Python.import(...)`.

In an app bundle, `defaultPythonHome()` resolves to:
```
<App>.app/Contents/Frameworks/Python.framework/Versions/3.13
```

### cfabric API surface

| Python | Swift |
|---|---|
| `cfabric.Fabric(path).loadAll()` | `Fabric(path:)` |
| `api.S.search(query)` | `fabric.search(_:) → [PythonObject]` |
| `api.T.text(node)` | `fabric.text(for:) → String` |

### Code signing

The BeeWare archive ships with ad-hoc signatures. `make sign-python` replaces them:
1. Signs every `.so` in `lib-dynload/` individually
2. Re-signs `Python.framework` with `--deep`

Both steps are required — signing only `.so` files and skipping the framework re-sign will fail notarization. Apps embedding Python.framework also need a Build Phase script to re-sign after Xcode copies the framework into the product.
