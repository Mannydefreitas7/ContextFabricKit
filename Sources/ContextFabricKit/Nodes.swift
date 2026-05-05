import PythonKit

/// Node iteration and sorting, exposed as `fabric.N`.
///
/// For type-filtered iteration, prefer `fabric.nodes(ofType:)` which uses the
/// `otype` feature index and is significantly faster than walking all nodes.
public final class NodesNamespace {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    /// All nodes in canonical corpus order (embedders before embedded, left before right).
    ///
    /// - Warning: Large corpora can have millions of nodes. Consider
    ///   `fabric.nodes(ofType:)` or `fabric.S.search(_:)` to work with a bounded set.
    public func walk() -> [Node] {
        Array<PythonObject>(py.walk())?.compactMap { Int($0) } ?? []
    }

    /// Sort `nodes` into canonical corpus order.
    public func sort(_ nodes: [Node]) -> [Node] {
        let pyNodes = PythonObject(nodes.map { PythonObject($0) })
        return Array<PythonObject>(py.sortNodes(pyNodes))?.compactMap { Int($0) } ?? []
    }
}
