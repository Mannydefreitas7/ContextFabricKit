import PythonKit

/// Pattern-based corpus search, exposed as `fabric.S`.
///
/// Templates use Text-Fabric search syntax. Each line is a node variable; indentation
/// expresses embedding. Feature constraints follow the node type on the same line.
///
/// ```swift
/// let results = fabric.S.search("""
///     phrase
///        word pos=verb
///        word pos=noun
/// """)
///
/// // Each result is [phraseNode, verbNode, nounNode]
/// for result in results {
///     print(fabric.T.text(of: result[0]))   // phrase text
///     print(fabric.S.glean(result))          // section + text summary
/// }
/// ```
public final class SearchNamespace {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    /// Execute a search template and return all matching result tuples.
    ///
    /// Each inner array contains one `Node` per variable defined in the template,
    /// in the order they appear.
    ///
    /// - Parameters:
    ///   - template: Search template in Text-Fabric query syntax.
    ///   - limit: Maximum number of results to return. `nil` returns all results.
    ///   - sets: Named node sets that can be referenced in the template as `s:setName`.
    public func search(
        _ template: String,
        limit: Int? = nil,
        sets: [String: Set<Node>]? = nil
    ) -> [[Node]] {
        let pyTemplate = PythonObject(template)
        let raw: PythonObject

        switch (limit, sets) {
        case (nil, nil):
            raw = py.search(pyTemplate)
        case (let n?, nil):
            raw = py.search(pyTemplate, limit: PythonObject(n))
        case (nil, let s?):
            raw = py.search(pyTemplate, sets: pySets(from: s))
        case (let n?, let s?):
            raw = py.search(pyTemplate, limit: PythonObject(n), sets: pySets(from: s))
        }

        return Array<PythonObject>(raw)?.compactMap { tuple in
            Array<PythonObject>(tuple)?.compactMap { Int($0) }
        } ?? []
    }

    /// Human-readable description of a result tuple — shows section location and text
    /// for each node in the result.
    public func glean(_ result: [Node]) -> String {
        // cfabric's glean() expects a tuple, not a list.
        let pyTuple = Python.tuple(PythonObject(result.map { PythonObject($0) }))
        return String(py.glean(pyTuple)) ?? ""
    }

    // MARK: Private

    private func pySets(from sets: [String: Set<Node>]) -> PythonObject {
        let pyDict = Python.dict()
        for (name, nodes) in sets {
            pyDict[PythonObject(name)] = Python.set(nodes.map { PythonObject($0) })
        }
        return pyDict
    }
}
