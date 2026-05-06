import PythonKit

// MARK: - FeatureNamespace

/// Access to node features, exposed as `fabric.F`.
///
/// ```swift
/// let pos  = fabric.F["pos"].value(of: node)          // FeatureValue?
/// let verbs = fabric.F["pos"].nodes(for: "verb")       // [Node]
/// let freq  = fabric.F["pos"].frequencyList()          // [(FeatureValue, Int)]
/// ```
public final class FeatureNamespace {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    /// Access a feature by name.
    public subscript(name: String) -> NodeFeature {
        NodeFeature(py[dynamicMember: name])
    }
}

// MARK: - NodeFeature

/// A single node feature (e.g. `pos`, `lex`, `otype`).
public final class NodeFeature {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    /// Feature value for `node`, or `nil` if the feature is not set for that node.
    public func value(of node: Node) -> FeatureValue? {
        featureValue(from: py.v(PythonObject(node)))
    }

    /// All nodes where this feature equals `value`, in canonical corpus order.
    public func nodes(for value: String) -> [Node] {
        nodes(pyValue: PythonObject(value))
    }

    /// All nodes where this feature equals `value`, in canonical corpus order.
    public func nodes(for value: Int) -> [Node] {
        nodes(pyValue: PythonObject(value))
    }

    private func nodes(pyValue: PythonObject) -> [Node] {
        Array<PythonObject>(py.s(pyValue))?.compactMap { Int($0) } ?? []
    }

    /// All `(node, value)` pairs for this feature, in no particular order.
    public func items() -> [(Node, FeatureValue)] {
        var result: [(Node, FeatureValue)] = []
        for pair in py.items() {
            guard let node = Int(pair[0]), let val = featureValue(from: pair[1]) else { continue }
            result.append((node, val))
        }
        return result
    }

    /// `(value, frequency)` pairs sorted by frequency descending.
    public func frequencyList() -> [(FeatureValue, Int)] {
        var result: [(FeatureValue, Int)] = []
        for pair in py.freqList() {
            guard let val = featureValue(from: pair[0]), let freq = Int(pair[1]) else { continue }
            result.append((val, freq))
        }
        return result
    }

    /// Metadata from the feature's `.tf` file header (e.g. `"description"`, `"valueType"`).
    public var meta: [String: String] {
        var result: [String: String] = [:]
        for pair in py.meta.items() {
            if let k = String(pair[0]), let v = String(pair[1]) {
                result[k] = v
            }
        }
        return result
    }
}

// MARK: - EdgeNamespace

/// Access to edge features, exposed as `fabric.E`.
///
/// ```swift
/// let slots    = fabric.E["oslots"].from(phraseNode)   // [Node] — slot nodes of a phrase
/// let parents  = fabric.E["oslots"].to(slotNode)       // [Node] — phrases containing this slot
/// ```
public final class EdgeNamespace {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    /// Access an edge feature by name.
    public subscript(name: String) -> EdgeFeature {
        EdgeFeature(py[dynamicMember: name])
    }
}

// MARK: - EdgeFeature

/// A single edge feature (e.g. `oslots`).
public final class EdgeFeature {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    /// Whether this edge feature carries values (as opposed to pure connectivity).
    public var hasValues: Bool {
        // Use .checking to safely handle cfabric versions that don't expose doValues.
        (py.checking.doValues).flatMap { Bool($0) } ?? false
    }

    /// Destination nodes for edges departing `node`.
    /// For `oslots` (OslotsFeature), uses `s(n)` — returns slot nodes, or `(n,)` for slot nodes.
    public func from(_ node: Node) -> [Node] {
        let pyNode = PythonObject(node)
        if py.checking.f != nil {
            return extractNodes(py.f(pyNode))
        }
        return extractNodes(py.s(pyNode))
    }

    /// Origin nodes for edges arriving at `node`.
    /// Returns empty for `oslots` — OslotsFeature has no reverse method; use `L.up()` instead.
    public func to(_ node: Node) -> [Node] {
        guard py.checking.t != nil else { return [] }
        return extractNodes(py.t(PythonObject(node)))
    }

    /// All nodes connected to `node` in either direction.
    /// For `oslots`, falls back to `from(_:)` since there is no `b(n)` method.
    public func bidirectional(_ node: Node) -> [Node] {
        guard py.checking.b != nil else { return from(node) }
        return extractNodes(py.b(PythonObject(node)))
    }

    /// Destination nodes and edge values for edges departing `node`.
    /// Edge value is `nil` for unvalued edges.
    public func valuesFrom(_ node: Node) -> [(Node, FeatureValue?)] {
        if py.checking.f == nil {
            return from(node).map { ($0, nil) }
        }
        return extractValued(py.f(PythonObject(node)))
    }

    /// Origin nodes and edge values for edges arriving at `node`.
    public func valuesTo(_ node: Node) -> [(Node, FeatureValue?)] {
        guard py.checking.t != nil else { return [] }
        return extractValued(py.t(PythonObject(node)))
    }

    // Handles both unvalued (tuple[int,...]) and valued (tuple[(int,Any),...]) returns.
    private func extractNodes(_ result: PythonObject) -> [Node] {
        Array<PythonObject>(result)?.compactMap { element in
            Int(element) ?? Int(element[0])
        } ?? []
    }

    private func extractValued(_ result: PythonObject) -> [(Node, FeatureValue?)] {
        Array<PythonObject>(result)?.compactMap { element -> (Node, FeatureValue?)? in
            if let n = Int(element) { return (n, nil) }
            guard let n = Int(element[0]) else { return nil }
            return (n, featureValue(from: element[1]))
        } ?? []
    }
}

// MARK: - Shared helper (internal to this module)

func featureValue(from py: PythonObject) -> FeatureValue? {
    guard py != Python.None else { return nil }
    if let i = Int(py) { return .int(i) }
    if let s = String(py) { return .string(s) }
    return nil
}
