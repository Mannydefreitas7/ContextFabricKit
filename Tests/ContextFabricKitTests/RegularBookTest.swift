import Testing
import Foundation
@testable import ContextFabricKit

// MARK: - Non-biblical corpus integration tests (requires `make bootstrap`)
//
// Corpus: Descartes correspondence critical edition (downloaded from GitHub on first run)
// Source: https://github.com/Mannydefreitas7/descartes-tf/tree/8967dcff5f633f20bf8149bb6657ba47d05f8c89/tf/1.1
// Node layout:
//   word    1–681935
//   volume  721501–721508   (8 volumes)
//   letter  695779–696503   (725 letters)
//   p       697049–705486   (paragraphs, section level 3)
// Section types:  volume, letter, p
// Section features: n (int), id (str), n (int)
// Text format: {trans}{punc}

@MainActor
@Suite(.serialized)
struct RegularBookTests {

    private static let packageRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // ContextFabricKitTests/
        .deletingLastPathComponent()  // Tests/
        .deletingLastPathComponent()  // package root

    static let pythonHome: String = packageRoot
        .appendingPathComponent(
            "Artifacts/Python.xcframework/macos-arm64_x86_64/Python.framework/Versions/3.13"
        ).path

    static let samplePath: String = packageRoot
        .appendingPathComponent("Tests/Samples/Descartes/1.1")
        .path

    private static let githubURL =
        "https://github.com/Mannydefreitas7/descartes-tf/tree/8967dcff5f633f20bf8149bb6657ba47d05f8c89/tf/1.1"

    nonisolated(unsafe) private static var sharedFabric: Fabric?

    let fabric: Fabric

    init() async throws {
        try #require(
            FileManager.default.fileExists(atPath: Self.pythonHome),
            "Python.xcframework not found — run `make bootstrap` first"
        )
        try await TestCorpusLoader.ensureDownloaded(from: Self.githubURL, to: Self.samplePath)
        if Self.sharedFabric == nil {
            PythonRuntime.initialize(pythonHome: Self.pythonHome)
            Self.sharedFabric = try Fabric(path: Self.samplePath)
        }
        fabric = Self.sharedFabric!
    }

    // MARK: - Fabric loading

    @Test func loadsCorpus() {
        // init() succeeding without throwing is the assertion.
    }

    @Test func cfmCacheExistsAfterLoad() {
        let cfm = URL(fileURLWithPath: Self.samplePath).appendingPathComponent(".cfm/1")
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: cfm.path))
        for subdir in ["warp", "features", "edges", "computed"] {
            #expect(fm.fileExists(atPath: cfm.appendingPathComponent(subdir).path))
        }
    }

    // MARK: - Feature names

    @Test func loadedFeatureNamesContainsOtype() {
        #expect(fabric.loadedFeatureNames().contains("otype"))
    }

    @Test func loadedFeatureNamesContainsCorpusFeatures() {
        let names = fabric.loadedFeatureNames()
        #expect(names.contains("trans"))
        #expect(names.contains("n"))
        #expect(names.contains("id"))
        #expect(names.contains("punc"))
    }

    @Test func loadedEdgeFeatureNamesContainsOslots() {
        #expect(fabric.loadedEdgeFeatureNames().contains("oslots"))
    }

    // MARK: - Corpus introspection

    @Test func nodesOfTypeWordBoundaries() {
        #expect(fabric.F["otype"].value(of: 1) == .string("word"))
        #expect(fabric.F["otype"].value(of: 681_935) == .string("word"))
        #expect(fabric.F["otype"].value(of: 721_501) == .string("volume"))
    }

    @Test func nodesOfTypeVolumeCount() {
        #expect(fabric.nodes(ofType: "volume").count == 8)
    }

    @Test func nodesOfTypeLetterIsNonEmpty() {
        #expect(!fabric.nodes(ofType: "letter").isEmpty)
    }

    @Test func nodesOfTypeUnknownIsEmpty() {
        #expect(fabric.nodes(ofType: "nonexistent").isEmpty)
    }

    // MARK: - F: trans (word text)

    @Test func transFeatureFirstNodeIsString() {
        let val = fabric.F["trans"].value(of: 1)
        #expect(val?.stringValue != nil)
    }

    @Test func transFeatureNilForVolumeNode() {
        // Volume nodes have no trans value
        #expect(fabric.F["trans"].value(of: 721_501) == nil)
    }

    @Test func transFrequencyListIsSortedDescending() {
        let freq = fabric.F["trans"].frequencyList()
        #expect(!freq.isEmpty)
        for i in 0 ..< freq.count - 1 {
            #expect(freq[i].1 >= freq[i + 1].1)
        }
    }

    // MARK: - F: n (section number — volumes and paragraphs)

    @Test func nFeatureForFirstVolumeIsInteger() {
        let val = fabric.F["n"].value(of: 721_501)
        #expect(val?.intValue != nil)
    }

    @Test func nFeatureForVolumesIsAscending() {
        let volumes = fabric.nodes(ofType: "volume")
        let nValues = volumes.compactMap { fabric.F["n"].value(of: $0)?.intValue }
        #expect(nValues.count == 8)
        #expect(zip(nValues, nValues.dropFirst()).allSatisfy { $0 < $1 })
    }

    // MARK: - F: id (letter identifier)

    @Test func idFeatureIsNonNilForLetterNode() {
        let letters = fabric.nodes(ofType: "letter")
        #expect(!letters.isEmpty)
        #expect(fabric.F["id"].value(of: letters[0]) != nil)
    }

    // MARK: - E: oslots

    @Test func oslotsHasNoValues() {
        #expect(fabric.E["oslots"].hasValues == false)
    }

    @Test func oslotsFromVolumeContainsWords() {
        let slots = fabric.E["oslots"].from(721_501)
        #expect(!slots.isEmpty)
        #expect(slots.allSatisfy { $0 <= 681_935 })
    }

    @Test func oslotsToSlotReturnsEmpty() {
        #expect(fabric.E["oslots"].to(1).isEmpty)
    }

    @Test func oslotsBidirectionalOnSlotReturnsSelf() {
        #expect(fabric.E["oslots"].bidirectional(1) == [1])
    }

    // MARK: - L: Locality

    @Test func upFromWordToVolume() {
        let volumes = fabric.L.up(1, type: "volume")
        #expect(!volumes.isEmpty)
        #expect(volumes[0] >= 721_501)
    }

    @Test func upFromWordToLetter() {
        #expect(!fabric.L.up(1, type: "letter").isEmpty)
    }

    @Test func downFromVolumeToWords() {
        let words = fabric.L.down(721_501, type: "word")
        #expect(!words.isEmpty)
        #expect(words.allSatisfy { $0 <= 681_935 })
    }

    @Test func downFromVolumeToLetters() {
        #expect(!fabric.L.down(721_501, type: "letter").isEmpty)
    }

    @Test func nextLetterExists() {
        let letters = fabric.nodes(ofType: "letter")
        let next = fabric.L.next(letters[0], type: "letter")
        #expect(!next.isEmpty)
    }

    @Test func previousVolumeOfSecondVolumeIsFirst() {
        let volumes = fabric.N.sort(fabric.nodes(ofType: "volume"))
        #expect(volumes.count >= 2)
        let prev = fabric.L.previous(volumes[1], type: "volume")
        #expect(prev.contains(volumes[0]))
    }

    @Test func intersectingVolumeReturnsNonEmpty() {
        // Structural nodes can intersect; a volume intersects its constituent letters.
        let result = fabric.L.intersecting(721_501, type: "letter")
        #expect(!result.isEmpty)
    }

    // MARK: - T: Text

    @Test func textOfFirstWordIsNonEmpty() {
        #expect(!fabric.T.text(of: 1).isEmpty)
    }

    @Test func textOfWordSequenceIsNonEmpty() {
        #expect(!fabric.T.text(of: [1, 2, 3]).isEmpty)
    }

    @Test func textOfNodeSequenceEqualsIndividualTexts() {
        #expect(fabric.T.text(of: [1, 2]) == fabric.T.text(of: 1) + fabric.T.text(of: 2))
    }

    @Test func sectionFromFirstWordHasThreeLevels() {
        // volume / letter / p
        #expect(fabric.T.section(from: 1).count == 3)
    }

    @Test func nodeFromSectionRoundtrips() throws {
        let section = fabric.T.section(from: 1)
        let node = try #require(fabric.T.node(from: section))
        #expect(fabric.T.section(from: node) == section)
    }

    @Test func nodeFromUnknownSectionIsNil() {
        #expect(fabric.T.node(from: ["UnknownVolume", "0", "0"]) == nil)
    }

    // MARK: - S: Search

    @Test func searchForVolumesReturnsExactCount() {
        #expect(fabric.S.search("volume").count == 8)
    }

    @Test func searchEachVolumeResultHasOneNode() {
        #expect(fabric.S.search("volume").allSatisfy { $0.count == 1 })
    }

    @Test func searchWithLimitCapsResults() {
        #expect(fabric.S.search("word", limit: 10).count == 10)
    }

    @Test func gleanReturnsNonEmptyStringForParagraph() {
        // p is sectionTypes[2] → glean formats as "vol letter:p"
        let results = fabric.S.search("p", limit: 1)
        #expect(!results.isEmpty)
        #expect(!fabric.S.glean(results[0]).isEmpty)
    }

    // MARK: - N: Nodes

    @Test func sortRespectsCanonicalOrder() {
        // cfabric canonical order puts structural embedder nodes before their slot nodes:
        // volume (721501) → letter (695779) → word (1).
        #expect(fabric.N.sort([721_501, 1, 695_779]) == [721_501, 695_779, 1])
    }

    @Test func sortIsIdempotent() {
        let nodes = [721_501, 695_779, 1]
        let once = fabric.N.sort(nodes)
        #expect(fabric.N.sort(once) == once)
    }

    @Test func sortEmptyReturnsEmpty() {
        #expect(fabric.N.sort([]).isEmpty)
    }
}
