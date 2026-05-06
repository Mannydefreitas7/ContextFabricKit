import PythonKit

/// Text and section access, exposed as `fabric.T`.
///
/// ```swift
/// // Render text
/// let verseText = fabric.T.text(of: verseNode)
/// let origText  = fabric.T.text(of: wordNode, format: "text-orig-full")
///
/// // Section headings
/// let heading = fabric.T.section(from: wordNode)  // e.g. ["Genesis", "1", "1"]
/// let node    = fabric.T.node(from: ["Genesis", "1", "1"])
/// ```
public final class TextNamespace {
    private let py: PythonObject
    init(_ py: PythonObject) { self.py = py }

    // MARK: Text rendering

    /// Text representation of a single node.
    ///
    /// - Parameters:
    ///   - node: The node to render.
    ///   - format: Named text format defined in the corpus (e.g. `"text-orig-full"`).
    ///             Uses the corpus default when `nil`.
    public func text(of node: Node, format: String? = nil) -> String {
        render(PythonObject(node), format: format)
    }

    /// Concatenated text for an ordered sequence of nodes.
    ///
    /// - Parameters:
    ///   - nodes: Nodes to render in order.
    ///   - format: Named text format. Uses the corpus default when `nil`.
    public func text(of nodes: [Node], format: String? = nil) -> String {
        render(PythonObject(nodes.map { PythonObject($0) }), format: format)
    }

    private func render(_ pyNodes: PythonObject, format: String?) -> String {
        let result = format.map { py.text(pyNodes, fmt: PythonObject($0)) }
                  ?? py.text(pyNodes)
        return String(result) ?? ""
    }

    // MARK: Section navigation

    /// Section heading tuple for `node`, e.g. `["Genesis", "1", "1"]` for Gen 1:1.
    ///
    /// The length depends on how many section levels the corpus defines (1–3).
    ///
    /// - Parameters:
    ///   - node: Any node in the corpus.
    ///   - lang: Two-letter language code for section labels (default `"en"`).
    public func section(from node: Node, lang: String = "en") -> [String] {
        let result = py.sectionFromNode(PythonObject(node), lang: PythonObject(lang))
        return Array<PythonObject>(result)?.compactMap { element -> String? in
            guard element != Python.None else { return nil }
            return String(element) ?? Int(element).map { String($0) }
        } ?? []
    }

    /// Node corresponding to a section tuple.
    ///
    /// - Parameters:
    ///   - section: Section specification, e.g. `["Genesis", "1", "1"]`.
    ///   - lang: Two-letter language code (default `"en"`).
    /// - Returns: The matching node, or `nil` if not found.
    public func node(from section: [String], lang: String = "en") -> Node? {
        // cfabric keys its internal section dicts on the feature's declared dataType ("int"/"str").
        // sectionFeatureTypes is unreliable on first .tf load (defaults all to "str") because
        // .tf headers use "valueType" (camelCase) while cfabric reads "value_type" (snake_case).
        // api.CF.features[fname].dataType is always correct regardless of load path.
        let sectionFeats = Array<PythonObject>(py.sectionFeats) ?? []
        let cfFeatures: PythonObject? = {
            guard let api = py.checking.api else { return nil }
            guard let cf = api.checking.CF else { return nil }
            return cf.checking.features
        }()
        let pySection = PythonObject(section.enumerated().map { i, s -> PythonObject in
            guard let intVal = Int(s) else { return PythonObject(s) }
            var isInt = true
            if i < sectionFeats.count, let cfFeatures = cfFeatures {
                let fname = sectionFeats[i]
                let fObj = cfFeatures.get(fname, Python.None)
                if fObj != Python.None,
                   let dt = fObj.checking.dataType.flatMap({ String($0) }) {
                    isInt = dt == "int"
                }
            }
            return isInt ? PythonObject(intVal) : PythonObject(s)
        })
        let result = py.nodeFromSection(pySection, lang: PythonObject(lang))
        return result == Python.None ? nil : Int(result)
    }
}
