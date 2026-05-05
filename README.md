<p align="center">
  <img src="https://raw.githubusercontent.com/Context-Fabric/context-fabric/master/assets/fabric_tan_mark.svg" width="110" alt="Context Fabric" />
</p>

<h1 align="center">ContextFabricKit</h1>

<p align="center">
  Swift Package · bridges the <a href="https://context-fabric.ai/docs">Context Fabric</a> Python library to native macOS apps
</p>

<p align="center">
  <a href="https://swift.org/package-manager">
    <img src="https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?logo=swift&logoColor=white" alt="Swift Package Manager" />
  </a>
  <a href="https://www.swift.org">
    <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white" alt="Swift 6.0" />
  </a>
  <img src="https://img.shields.io/badge/platform-macOS_13%2B-blue?logo=apple&logoColor=white" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Python-3.13-blue?logo=python&logoColor=white" alt="Python 3.13" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
  </a>
</p>

---

Embeds a signed Python 3.13 interpreter (via [BeeWare Python-Apple-support](https://github.com/beeware/python-apple-support)) so macOS apps can run `cfabric` corpus queries natively — including App Store distribution.

## Requirements

- macOS 13+
- Xcode 16+
- Python 3.13 on PATH (e.g. `brew install python@3.13`) — used only during bootstrap to pip-install `context-fabric` into the embedded interpreter

## Bootstrap

The embedded `Python.xcframework` must exist before `swift build` will succeed. Run once per machine:

```bash
make bootstrap
```

This chains four steps:
1. Downloads the BeeWare Python 3.13 archive
2. Extracts `Python.xcframework` (stdlib lives inside it)
3. Installs `context-fabric` (+ `numpy`, `pyyaml`) into the embedded `site-packages`
4. Re-signs all `.so` extension modules and the framework (ad-hoc by default)

For App Store or notarization builds, pass your certificate identity:

```bash
make bootstrap SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
```

## Usage

`Fabric.init(path:)` throws if the corpus cannot be loaded. All namespaces are available as properties on the returned instance.

```swift
import ContextFabricKit

let fabric = try Fabric(path: "/path/to/corpus")
```

### Feature access — `F`

```swift
// Value of a feature for a specific node
let pos: FeatureValue? = fabric.F["pos"].value(of: node)      // .string("verb")
let num: FeatureValue? = fabric.F["g_word_n"].value(of: node) // .int(42)

// All nodes where a feature equals a value
let verbs: [Node] = fabric.F["pos"].nodes(for: "verb")

// Frequency distribution
let freq: [(FeatureValue, Int)] = fabric.F["pos"].frequencyList()

// Iterate all (node, value) pairs
for (node, value) in fabric.F["otype"].items() { ... }
```

### Edge feature access — `E`

```swift
// Slot nodes contained in a phrase (oslots is the standard containment edge)
let slots: [Node] = fabric.E["oslots"].from(phraseNode)

// Reverse: which phrases contain this slot?
let parents: [Node] = fabric.E["oslots"].to(slotNode)

// For valued edges, keep the edge value
let valued: [(Node, FeatureValue?)] = fabric.E["mother"].valuesFrom(node)
```

### Locality navigation — `L`

All methods return nodes in canonical order. The `type:` parameter filters to a single node type.

```swift
let phrases:  [Node] = fabric.L.up(wordNode, type: "phrase")
let words:    [Node] = fabric.L.down(phraseNode, type: "word")
let siblings: [Node] = fabric.L.intersecting(wordNode, type: "word")
let prev:     [Node] = fabric.L.previous(clauseNode, type: "clause")
let next:     [Node] = fabric.L.next(clauseNode, type: "clause")
```

### Text extraction — `T`

```swift
// Render a single node or a sequence of nodes
let text: String = fabric.T.text(of: verseNode)
let orig: String = fabric.T.text(of: wordNode, format: "text-orig-full")
let span: String = fabric.T.text(of: [word1, word2, word3])

// Section headings  (e.g. ["Genesis", "1", "1"] for Gen 1:1)
let heading: [String] = fabric.T.section(from: wordNode)
let node:    Node?    = fabric.T.node(from: ["Genesis", "1", "1"])
```

### Pattern search — `S`

Templates use [Text-Fabric search syntax](https://annotation.github.io/text-fabric/tf/about/searchusage.html). Indentation expresses embedding; feature constraints follow the node type on the same line.

```swift
let results: [[Node]] = fabric.S.search("""
    phrase
       word pos=verb
       word pos=noun
""")

// Each result is [phraseNode, verbNode, nounNode]
for result in results {
    print(fabric.T.text(of: result[0]))  // phrase text
    print(fabric.S.glean(result))        // section + text summary
}

// Cap result count or supply named node sets
let limited = fabric.S.search("word pos=verb", limit: 100)
let scoped  = fabric.S.search("word n:nodeSet", sets: ["nodeSet": myNodes])
```

### Node iteration — `N`

```swift
// All nodes in canonical order (can be millions — prefer nodes(ofType:) or S.search)
let all: [Node] = fabric.N.walk()

// Sort an arbitrary collection of nodes
let sorted: [Node] = fabric.N.sort([node3, node1, node2])
```

### Corpus introspection

```swift
// Shortcut: all nodes of a given type via the otype feature index
let words: [Node] = fabric.nodes(ofType: "word")

let nodeFeatures: [String] = fabric.loadedFeatureNames()
let edgeFeatures: [String] = fabric.loadedEdgeFeatureNames()
fabric.ensureLoaded(["gloss", "gender"])
```

## Adding to an App

1. Add this package as a dependency in Xcode or `Package.swift`.
2. In your app target's **Frameworks, Libraries, and Embedded Content**, add `Python.xcframework` (from `Artifacts/`) and set it to **Do Not Embed** — Xcode embeds it automatically via the SPM binary target.
3. Add a **Run Script** Build Phase to re-sign the copied framework after Xcode processes it:

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

## Credits

ContextFabricKit is a Swift wrapper around **[Context Fabric](https://github.com/Context-Fabric/context-fabric)**, created by [Cody Kingham](https://github.com/codykingham) — an AI-native corpus engine for annotated text, compatible with 35+ Text-Fabric datasets.

Context Fabric is itself the next evolution of **[Text-Fabric](https://github.com/annotation/text-fabric)** by [Dirk Roorda](https://github.com/dirkroorda), which pioneered graph-based corpus linguistics tooling.

## License

MIT
