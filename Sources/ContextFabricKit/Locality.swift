import PythonKit

/// Locality navigation through the corpus node hierarchy, exposed as `fabric.L`.
///
/// All methods return nodes in canonical order (embedders before embedded, left before right).
/// The optional `type` parameter filters results to a single node type.
///
/// ```swift
/// let phrases  = fabric.L.up(wordNode, type: "phrase")
/// let words    = fabric.L.down(phraseNode, type: "word")
/// let adjacent = fabric.L.next(clauseNode, type: "clause")
/// ```
public final class LocalityNamespace {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    /// Nodes that contain all slots of `node` (upward / embedders).
    public func up(_ node: Node, type: String? = nil) -> [Node] {
        call("u", node: node, type: type)
    }

    /// Nodes embedded entirely within `node` (downward / embeddees).
    public func down(_ node: Node, type: String? = nil) -> [Node] {
        call("d", node: node, type: type)
    }

    /// Nodes sharing at least one slot with `node`.
    public func intersecting(_ node: Node, type: String? = nil) -> [Node] {
        call("i", node: node, type: type)
    }

    /// Nodes whose last slot immediately precedes `node`'s first slot.
    public func previous(_ node: Node, type: String? = nil) -> [Node] {
        call("p", node: node, type: type)
    }

    /// Nodes whose first slot immediately follows `node`'s last slot.
    public func next(_ node: Node, type: String? = nil) -> [Node] {
        call("n", node: node, type: type)
    }

    private func call(_ method: String, node: Node, type: String?) -> [Node] {
        let fn = py[dynamicMember: method]
        let result = type.map { fn(PythonObject(node), otype: PythonObject($0)) }
                  ?? fn(PythonObject(node))
        return Array<PythonObject>(result)?.compactMap { Int($0) } ?? []
    }
}
