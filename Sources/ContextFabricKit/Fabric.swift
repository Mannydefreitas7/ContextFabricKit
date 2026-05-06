import Foundation
import PythonKit

/// An integer that uniquely identifies a node in the corpus graph.
/// Slot nodes (text positions) occupy 1…maxSlot; structural nodes occupy maxSlot+1…maxNode.
public typealias Node = Int

/// The value stored in a node or edge feature — either a string or an integer.
public enum FeatureValue: Sendable, Equatable, CustomStringConvertible {
    case string(String)
    case int(Int)

    public var description: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }
}

public enum ContextFabricError: Error, Equatable {
    case loadFailed(path: String)
}

// MARK: -

/// Swift interface to a loaded `cfabric` corpus.
///
/// ```swift
/// let fabric = try Fabric(path: "/path/to/corpus")
///
/// // Feature access
/// let pos = fabric.F["pos"].value(of: someNode)  // FeatureValue?
///
/// // Locality navigation
/// let phrases = fabric.L.up(wordNode, type: "phrase")
///
/// // Text extraction
/// let text = fabric.T.text(of: verseNode)
///
/// // Pattern search
/// let results = fabric.S.search("word pos=verb")
/// for result in results { print(fabric.S.glean(result)) }
/// ```
public final class Fabric {
    // Retain the Python API object so the corpus stays loaded.
    private let api: PythonObject

    /// Node feature namespace — `F["featureName"].value(of:)`.
    public let F: FeatureNamespace
    /// Edge feature namespace — `E["featureName"].from(_:)`.
    public let E: EdgeNamespace
    /// Locality navigation — up, down, intersecting, previous, next.
    public let L: LocalityNamespace
    /// Text and section access.
    public let T: TextNamespace
    /// Pattern search.
    public let S: SearchNamespace
    /// Node iteration and sorting.
    public let N: NodesNamespace

    /// Load the corpus at `path` and call `loadAll()`.
    ///
    /// - Throws: `ContextFabricError.loadFailed` if cfabric cannot open the corpus.
    public init(path: String) throws {
        PythonRuntime.initialize()
        let cfabric = Python.import("cfabric")
        // Use PythonKit's `.throwing` API so Python exceptions surface as Swift errors
        // rather than crashing via `fatalError`.
        api = try {
            do {
                // Fabric.__init__ only sets up state; the actual file I/O (and any
                // Python exceptions) happens inside loadAll(). Use .throwing so
                // OSErrors and other Python exceptions surface as Swift errors
                // rather than crashing via fatalError.
                let pyFabric = cfabric.Fabric(path)
                // .throwing is callable but has no dynamic member lookup, so
                // retrieve the bound method first, then dispatch via throwing.
                let result = try pyFabric.loadAll.throwing.dynamicallyCall(withArguments: [])
                guard result != Python.False else {
                    throw ContextFabricError.loadFailed(path: path)
                }
                return result
            } catch let e as ContextFabricError {
                throw e
            } catch {
                throw ContextFabricError.loadFailed(path: path)
            }
        }()
        F = FeatureNamespace(api.F)
        E = EdgeNamespace(api.E)
        L = LocalityNamespace(api.L)
        T = TextNamespace(api.T)
        S = SearchNamespace(api.S)
        N = NodesNamespace(api.N)
    }

    // MARK: Corpus introspection

    /// Names of all loaded node features.
    public func loadedFeatureNames(includeWarp: Bool = true) -> [String] {
        Array<PythonObject>(api.Fall(warp: PythonObject(includeWarp)))?
            .compactMap { String($0) } ?? []
    }

    /// Names of all loaded edge features.
    public func loadedEdgeFeatureNames(includeWarp: Bool = true) -> [String] {
        Array<PythonObject>(api.Eall(warp: PythonObject(includeWarp)))?
            .compactMap { String($0) } ?? []
    }

    /// All nodes of a given type in canonical corpus order.
    /// Equivalent to `F["otype"].nodes(for: type)`.
    public func nodes(ofType type: String) -> [Node] {
        F["otype"].nodes(for: type)
    }

    /// Ensure the named features are loaded; returns names that are now available.
    @discardableResult
    public func ensureLoaded(_ featureNames: [String]) -> [String] {
        Array<PythonObject>(api.ensureLoaded(PythonObject(featureNames)))?
            .compactMap { String($0) } ?? []
    }
}
