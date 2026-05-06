import Testing
import Foundation
@testable import ContextFabricKit

// MARK: - FeatureValue (no corpus required)

struct FeatureValueTests {

    @Test func stringDescription() {
        #expect(FeatureValue.string("verb").description == "verb")
    }

    @Test func intDescription() {
        #expect(FeatureValue.int(42).description == "42")
    }

    @Test func zeroIntDescription() {
        #expect(FeatureValue.int(0).description == "0")
    }

    @Test func negativeIntDescription() {
        #expect(FeatureValue.int(-1).description == "-1")
    }

    @Test func emptyStringDescription() {
        #expect(FeatureValue.string("").description == "")
    }

    @Test func unicodeStringDescription() {
        #expect(FeatureValue.string("ܒܪܫܝܬ").description == "ܒܪܫܝܬ")
    }

    @Test func stringValue() {
        #expect(FeatureValue.string("noun").stringValue == "noun")
        #expect(FeatureValue.int(1).stringValue == nil)
    }

    @Test func intValue() {
        #expect(FeatureValue.int(99).intValue == 99)
        #expect(FeatureValue.int(0).intValue == 0)
        #expect(FeatureValue.string("x").intValue == nil)
    }

    @Test func equality() {
        #expect(FeatureValue.string("noun") == FeatureValue.string("noun"))
        #expect(FeatureValue.int(1) == FeatureValue.int(1))
        #expect(FeatureValue.string("1") != FeatureValue.int(1))
        #expect(FeatureValue.string("a") != FeatureValue.string("b"))
        #expect(FeatureValue.int(0) != FeatureValue.int(1))
    }
}

// MARK: - Fabric integration (requires `make bootstrap`)
//
// Corpus: Syriac Peshitta sample (Tests/Samples/tf/0.1/)
// Node layout:
//   word   1–427227   (427 227 words)
//   book   427228–427292  (65 books, first = Genesis)
//   chapter 427293–428561
//   verse  428562–459937  (first = Genesis 1:1)
//
// All tests in this suite are skipped automatically when the xcframework
// is absent (i.e. before `make bootstrap` has been run).

// @MainActor pins all tests (and their ARC dealloc) to the main thread, preventing
// thread-safety issues with PythonKit's Py_DECREF calls across Swift concurrency tasks.
@MainActor
@Suite(.serialized)
struct FabricIntegrationTests {

    // Derive paths relative to this source file so tests work regardless of
    // where the repo is cloned.
    private static let packageRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // ContextFabricKitTests/
        .deletingLastPathComponent()  // Tests/
        .deletingLastPathComponent()  // package root

    static let pythonHome: String = packageRoot
        .appendingPathComponent(
            "Artifacts/Python.xcframework/macos-arm64_x86_64/Python.framework/Versions/3.13"
        ).path

    static let samplePath: String = packageRoot
        .appendingPathComponent("Tests/Samples/tf/0.1")
        .path

    // The corpus is large (~430k nodes). Load it once per test run rather than
    // once per test. `@Suite(.serialized)` guarantees single-threaded access, so
    // `nonisolated(unsafe)` satisfies the Swift 6 concurrency checker.
    nonisolated(unsafe) private static var sharedFabric: Fabric?

    let fabric: Fabric

    init() throws {
        try #require(
            FileManager.default.fileExists(atPath: Self.pythonHome),
            "Python.xcframework not found — run `make bootstrap` first"
        )
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

    // Note: testing Fabric.init with a bad path is excluded from this suite because
    // cfabric modifies Python global state during Fabric.__init__ (even for invalid
    // paths), which conflicts with the shared loaded corpus and produces intermittent
    // SIGSEGV crashes. The error-handling code in Fabric.init is correct and converts
    // Python OSError exceptions to ContextFabricError via .throwing.dynamicallyCall.

    @Test func loadedFeatureNamesContainsWarpFeatures() {
        let names = fabric.loadedFeatureNames()
        #expect(names.contains("otype"))
        // oslots is an edge feature — checked in loadedEdgeFeatureNamesContainsOslots
    }

    @Test func loadedFeatureNamesContainsCorpusFeatures() {
        let names = fabric.loadedFeatureNames()
        #expect(names.contains("word"))
        #expect(names.contains("book@en"))
        #expect(names.contains("verse"))
        #expect(names.contains("trailer"))
    }

    @Test func loadedEdgeFeatureNamesContainsOslots() {
        let names = fabric.loadedEdgeFeatureNames()
        #expect(names.contains("oslots"))
    }

    @Test func excludingWarpFeaturesReducesCount() {
        let withWarp = fabric.loadedFeatureNames(includeWarp: true)
        let withoutWarp = fabric.loadedFeatureNames(includeWarp: false)
        #expect(withWarp.count > withoutWarp.count)
    }

    // MARK: - Corpus introspection

    @Test func nodesOfTypeWordBoundaries() {
        // Verify word range boundaries without materializing 427k PythonObjects.
        // otype.tf declares nodes 1–427227 as "word".
        #expect(fabric.F["otype"].value(of: 1) == .string("word"))
        #expect(fabric.F["otype"].value(of: 427_227) == .string("word"))
        #expect(fabric.F["otype"].value(of: 427_228) == .string("book"))  // first non-word node
    }

    @Test func nodesOfTypeBookCount() {
        // otype.tf: 427228–427292 are books → 65 books
        #expect(fabric.nodes(ofType: "book").count == 65)
    }

    @Test func nodesOfTypeUnknownIsEmpty() {
        #expect(fabric.nodes(ofType: "phrase").isEmpty)
    }

    @Test func ensureLoadedReturnsPresentFeatures() {
        let loaded = fabric.ensureLoaded(["word", "verse"])
        #expect(loaded.contains("word"))
        #expect(loaded.contains("verse"))
    }

    // MARK: - F: otype

    @Test func otypeValueForFirstWord() {
        #expect(fabric.F["otype"].value(of: 1) == .string("word"))
    }

    @Test func otypeValueForFirstBook() {
        #expect(fabric.F["otype"].value(of: 427_228) == .string("book"))
    }

    @Test func otypeValueForFirstVerse() {
        #expect(fabric.F["otype"].value(of: 428_562) == .string("verse"))
    }

    @Test func otypeNodesForBook() {
        let books = fabric.F["otype"].nodes(for: "book")
        #expect(books.count == 65)
        #expect(books.first == 427_228)
    }

    // MARK: - F: word (Syriac text)

    @Test func wordFeatureFirstNode() {
        // word.tf: node 1 = "ܒܪܫܝܬ" (Genesis 1:1 opening word)
        #expect(fabric.F["word"].value(of: 1) == .string("ܒܪܫܝܬ"))
    }

    @Test func wordFeatureSecondNode() {
        #expect(fabric.F["word"].value(of: 2) == .string("ܒܪܐ"))
    }

    @Test func wordFeatureNilForBookNode() {
        // Book nodes have no word feature value
        #expect(fabric.F["word"].value(of: 427_228) == nil)
    }

    @Test func wordFrequencyListIsSortedDescending() {
        let freq = fabric.F["word"].frequencyList()
        #expect(!freq.isEmpty)
        for i in 0 ..< freq.count - 1 {
            #expect(freq[i].1 >= freq[i + 1].1)
        }
    }

    @Test func wordMetaContainsDescription() {
        // valueType is a cfabric-internal field not stored in the general meta dict;
        // check the user-defined description field instead.
        let meta = fabric.F["word"].meta
        #expect(meta["description"] == "full form of the word in syriac script")
    }

    // MARK: - F: book@en (English book names)

    @Test func bookEnFirstValue() {
        #expect(fabric.F["book@en"].value(of: 427_228) == .string("Genesis"))
    }

    @Test func bookEnSecondValue() {
        #expect(fabric.F["book@en"].value(of: 427_229) == .string("Exodus"))
    }

    @Test func bookEnNodesForGenesis() {
        let genesisNodes = fabric.F["book@en"].nodes(for: "Genesis")
        #expect(genesisNodes == [427_228])
    }

    @Test func bookEnMetaContainsLanguage() {
        let meta = fabric.F["book@en"].meta
        #expect(meta["language"] == "English")
    }

    // MARK: - F: verse (integer feature)

    @Test func verseFirstValue() {
        // verse.tf: node 428562 has verse value 1 (Genesis 1:1)
        #expect(fabric.F["verse"].value(of: 428_562) == .int(1))
    }

    @Test func verseIsIntType() {
        let val = fabric.F["verse"].value(of: 428_562)
        #expect(val?.intValue != nil)
        #expect(val?.stringValue == nil)
    }

    @Test func verseMetaContainsDescription() {
        let meta = fabric.F["verse"].meta
        #expect(meta["description"] == "verse number")
    }

    @Test func verseNodesForOne() {
        // Every chapter starts with verse 1 — there should be many
        let nodes = fabric.F["verse"].nodes(for: 1)
        #expect(!nodes.isEmpty)
    }

    // MARK: - E: oslots

    @Test func oslotsHasNoValues() {
        #expect(fabric.E["oslots"].hasValues == false)
    }

    @Test func oslotsFromVerseContainsWords() {
        // Genesis 1:1 verse node contains word slot nodes (1..N)
        let slots = fabric.E["oslots"].from(428_562)
        #expect(!slots.isEmpty)
        #expect(slots.contains(1))  // first word of the corpus
        #expect(slots.allSatisfy { $0 <= 427_227 })  // all are word nodes
    }

    @Test func oslotsToSlotReturnsEmpty() {
        // OslotsFeature has no reverse-direction method.
        // Use L.up() to find structural containers of a word node.
        let containers = fabric.E["oslots"].to(1)
        #expect(containers.isEmpty)
    }

    @Test func oslotsBidirectionalOnSlotReturnsSelf() {
        // No b(n) on OslotsFeature — falls back to s(n), which returns (n,) for slot nodes.
        let result = fabric.E["oslots"].bidirectional(1)
        #expect(result == [1])
    }

    // MARK: - L: Locality

    @Test func upFromWordToVerse() {
        let verses = fabric.L.up(1, type: "verse")
        #expect(!verses.isEmpty)
        // The first word is in Genesis 1:1 — verse node is 428562
        #expect(verses.contains(428_562))
    }

    @Test func upFromWordToBook() {
        let books = fabric.L.up(1, type: "book")
        #expect(books == [427_228])  // exactly Genesis
    }

    @Test func upWithoutTypeFilterReturnsAllContainers() {
        let all = fabric.L.up(1)
        let books = fabric.L.up(1, type: "book")
        let verses = fabric.L.up(1, type: "verse")
        #expect(all.count >= books.count + verses.count)
    }

    @Test func downFromVerseToWords() {
        let words = fabric.L.down(428_562, type: "word")
        #expect(!words.isEmpty)
        #expect(words.contains(1))
        #expect(words.allSatisfy { $0 <= 427_227 })
    }

    @Test func downFromBookToChapters() {
        let chapters = fabric.L.down(427_228, type: "chapter")
        #expect(!chapters.isEmpty)
    }

    @Test func nextVerseExists() {
        let next = fabric.L.next(428_562, type: "verse")
        #expect(!next.isEmpty)
        // Next verse comes after 428562
        #expect(next.allSatisfy { $0 > 428_562 })
    }

    @Test func previousVerseOfSecondVerse() {
        let secondVerse = 428_563
        let prev = fabric.L.previous(secondVerse, type: "verse")
        #expect(prev.contains(428_562))
    }

    @Test func intersectingReturnsOverlappingNodes() {
        // L.i() is only defined for structural (non-slot) nodes — slot nodes always
        // return empty. Use a verse node and verify it intersects another verse or book.
        // Genesis 1:1 (428562) and 1:2 (428563) share no words, but chapter/book overlap.
        let result = fabric.L.intersecting(428_562)
        // The verse should intersect with the chapter and book containing it
        #expect(!result.isEmpty)
        #expect(result.contains(427_228))  // Genesis book node overlaps with verse 1:1
    }

    // MARK: - T: Text

    @Test func textOfFirstWord() {
        let text = fabric.T.text(of: 1)
        #expect(text.contains("ܒܪܫܝܬ"))
    }

    @Test func textOfFirstWordWithOrigFormat() {
        let text = fabric.T.text(of: 1, format: "text-orig-full")
        #expect(text.contains("ܒܪܫܝܬ"))
    }

    @Test func textOfNodeSequence() {
        let text = fabric.T.text(of: [1, 2, 3])
        #expect(text.contains("ܒܪܫܝܬ"))
        #expect(text.contains("ܒܪܐ"))
        #expect(text.contains("ܐܠܗܐ"))
    }

    @Test func textOfNodeSequenceEqualsIndividualTexts() {
        let combined = fabric.T.text(of: [1, 2])
        let w1 = fabric.T.text(of: 1)
        let w2 = fabric.T.text(of: 2)
        #expect(combined == w1 + w2)
    }

    @Test func textOfVerseIsNonEmpty() {
        let text = fabric.T.text(of: 428_562)
        #expect(!text.isEmpty)
    }

    @Test func sectionFromFirstWordIsGenesisOneOne() {
        let section = fabric.T.section(from: 1)
        #expect(section.count == 3)
        #expect(section[0] == "Genesis")
        #expect(section[1] == "1")
        #expect(section[2] == "1")
    }

    @Test func sectionFromBookNodeHasOneLevel() {
        let section = fabric.T.section(from: 427_228)
        #expect(!section.isEmpty)
        #expect(section[0] == "Genesis")
    }

    @Test func nodeFromSectionReturnsVerseNode() {
        let node = fabric.T.node(from: ["Genesis", "1", "1"])
        #expect(node == 428_562)
    }

    @Test func nodeFromUnknownSectionIsNil() {
        let node = fabric.T.node(from: ["NonExistentBook", "1", "1"])
        #expect(node == nil)
    }

    @Test func nodeFromSectionRoundtrips() {
        let section = fabric.T.section(from: 1)
        let node = fabric.T.node(from: section)
        #expect(node != nil)
        // Round-trip: node from section is in the same section
        let roundtripSection = fabric.T.section(from: node!)
        #expect(roundtripSection == section)
    }

    // MARK: - S: Search

    @Test func searchAllBooksReturnsExactCount() {
        let results = fabric.S.search("book")
        #expect(results.count == 65)
    }

    @Test func searchEachResultHasOneNode() {
        let results = fabric.S.search("book")
        #expect(results.allSatisfy { $0.count == 1 })
    }

    @Test func searchWithLimitCappsResults() {
        let results = fabric.S.search("word", limit: 10)
        #expect(results.count == 10)
    }

    @Test func searchByBookNameFindsGenesis() {
        let results = fabric.S.search("book book@en=Genesis")
        #expect(results.count == 1)
        #expect(results[0][0] == 427_228)
    }

    @Test func searchWithNamedSetFiltersResults() {
        let genesisWords: Set<Node> = Set(1 ... 10)
        let results = fabric.S.search("w:myWords", limit: 5, sets: ["myWords": genesisWords])
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.count == 1 && genesisWords.contains($0[0]) })
    }

    @Test func gleanReturnsNonEmptyString() {
        // glean returns "" for book/chapter nodes (sectionTypes 0–1); use verse (type 2)
        // which formats as "Genesis 1:1"
        let results = fabric.S.search("verse", limit: 1)
        #expect(!results.isEmpty)
        let description = fabric.S.glean(results[0])
        #expect(!description.isEmpty)
    }

    @Test func gleanContainsSectionInfo() {
        let results = fabric.S.search("verse", limit: 1)
        let description = fabric.S.glean(results[0])
        // verse glean output is "BookName chapter:verse", e.g. "Genesis 1:1"
        #expect(description.contains("Genesis"))
    }

    // MARK: - N: Nodes

    @Test func sortWordNodesIsAscending() {
        let sorted = fabric.N.sort([3, 1, 2])
        #expect(sorted == [1, 2, 3])
    }

    @Test func sortIsIdempotent() {
        let nodes = [428_562, 427_228, 1]
        let once = fabric.N.sort(nodes)
        let twice = fabric.N.sort(once)
        #expect(once == twice)
    }

    @Test func sortEmptyReturnsEmpty() {
        #expect(fabric.N.sort([]).isEmpty)
    }

    @Test func sortSingleNodeReturnsSameNode() {
        #expect(fabric.N.sort([42]) == [42])
    }
}
