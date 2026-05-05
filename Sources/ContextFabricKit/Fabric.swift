import Foundation
import PythonKit

/// Swift interface to `cfabric.Fabric`.
///
/// Requires `make bootstrap` to have been run so that the embedded Python
/// interpreter and `cfabric` are available in the bundle resources.
public final class Fabric {
    private let api: PythonObject

    /// Load the corpus at `path` and call `loadAll()`.
    public init(path: String) {
        PythonRuntime.initialize()
        let cfabric = Python.import("cfabric")
        api = cfabric.Fabric(path).loadAll()
    }

    /// Execute a pattern query over the corpus graph.
    public func search(_ query: String) -> [PythonObject] {
        Array<PythonObject>(api.S.search(query)) ?? []
    }

    /// Extract plain text for a search-result node.
    public func text(for node: PythonObject) -> String {
        String(api.T.text(node)) ?? ""
    }
}
