import Testing
import Foundation
@testable import ContextFabricKit

// MARK: - Bible integration tests (requires `make bootstrap`)
//
// Corpus: Syriac Peshitta (downloaded from GitHub on first run)
// Source: https://github.com/Mannydefreitas7/peshitta/tree/9850f5addade26f681334aa475570bef9b0b440a/tf/0.2
// Node layout (0.2):
//   word    1–426835    (426 835 words)
//   book    426836–426900   (65 books, first = Genesis)
//   chapter 426901–428169
//   verse   428170–459510   (first = Genesis 1:1)
//
// All tests are skipped automatically when the xcframework is absent
// (i.e. before `make bootstrap` has been run).

// @MainActor pins all tests (and their ARC dealloc) to the main thread, preventing
// thread-safety issues with PythonKit's Py_DECREF calls across Swift concurrency tasks.
@MainActor
@Suite(.serialized)
struct BibleTests {

    private static let packageRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // ContextFabricKitTests/
        .deletingLastPathComponent()  // Tests/
        .deletingLastPathComponent()  // package root

    static let pythonHome: String = packageRoot
        .appendingPathComponent(
            "Artifacts/Python.xcframework/macos-arm64_x86_64/Python.framework/Versions/3.13"
        ).path

    static let samplePath: String = packageRoot
        .appendingPathComponent("Tests/Samples/Peshitta/0.2")
        .path

    private static let githubURL =
        "https://github.com/Mannydefreitas7/peshitta/tree/9850f5addade26f681334aa475570bef9b0b440a/tf/0.2"

    // The corpus is large (~430k nodes). Load it once per test run.
    // `@Suite(.serialized)` guarantees single-threaded access, so
    // `nonisolated(unsafe)` satisfies the Swift 6 concurrency checker.
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
        // cfabric compiles .tf data into an optimized binary format under .cfm/1/.
        // Verify all four expected subdirectories are present after Fabric(path:) succeeds.
        let cfm = URL(fileURLWithPath: Self.samplePath).appendingPathComponent(".cfm/1")
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: cfm.path))
        for subdir in ["warp", "features", "edges", "computed"] {
            #expect(fm.fileExists(atPath: cfm.appendingPathComponent(subdir).path))
        }
    }

    // Note: testing Fabric.init with a bad path is excluded from this suite because
    // cfabric modifies Python global state during Fabric.__init__ (even for invalid
    // paths), which conflicts with the shared loaded corpus and produces intermittent
    // SIGSEGV crashes.

    // MARK: - Feature names

    @Test func loadedFeatureNamesContainsWarpFeatures() {
        let names = fabric.loadedFeatureNames()
        #expect(names.contains("otype"))
    }

    @Test func loadedFeatureNamesContainsCorpusFeatures() {
        let names = fabric.loadedFeatureNames()
        #expect(names.contains("word"))
        #expect(names.contains("book@en"))
        #expect(names.contains("verse"))
        #expect(names.contains("trailer"))
    }

    @Test func loadedEdgeFeatureNamesContainsOslots() {
        #expect(fabric.loadedEdgeFeatureNames().contains("oslots"))
    }

    @Test func excludingWarpFeaturesReducesCount() {
        let withWarp = fabric.loadedFeatureNames(includeWarp: true)
        let withoutWarp = fabric.loadedFeatureNames(includeWarp: false)
        #expect(withWarp.count > withoutWarp.count)
    }

    // MARK: - Corpus introspection

    @Test func nodesOfTypeWordBoundaries() {
        #expect(fabric.F["otype"].value(of: 1) == .string("word"))
        #expect(fabric.F["otype"].value(of: 426_835) == .string("word"))
        #expect(fabric.F["otype"].value(of: 426_836) == .string("book"))
    }

    @Test func nodesOfTypeBookCount() {
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
        #expect(fabric.F["otype"].value(of: 426_836) == .string("book"))
    }

    @Test func otypeValueForFirstVerse() {
        #expect(fabric.F["otype"].value(of: 428_170) == .string("verse"))
    }

    @Test func otypeNodesForBook() {
        let books = fabric.F["otype"].nodes(for: "book")
        #expect(books.count == 65)
        #expect(books.first == 426_836)
    }

    // MARK: - F: word (Syriac text)

    @Test func wordFeatureFirstNode() {
        // Genesis 1:1 opening word
        #expect(fabric.F["word"].value(of: 1) == .string("ܒܪܫܝܬ"))
    }

    @Test func wordFeatureSecondNode() {
        #expect(fabric.F["word"].value(of: 2) == .string("ܒܪܐ"))
    }

    @Test func wordFeatureNilForBookNode() {
        #expect(fabric.F["word"].value(of: 426_836) == nil)
    }

    @Test func wordFrequencyListIsSortedDescending() {
        let freq = fabric.F["word"].frequencyList()
        #expect(!freq.isEmpty)
        for i in 0 ..< freq.count - 1 {
            #expect(freq[i].1 >= freq[i + 1].1)
        }
    }

    @Test func wordMetaContainsDescription() {
        let meta = fabric.F["word"].meta
        #expect(meta["description"] == "full form of the word in syriac script")
    }

    // MARK: - F: book@en (English book names)

    @Test func bookEnFirstValue() {
        #expect(fabric.F["book@en"].value(of: 426_836) == .string("Genesis"))
    }

    @Test func bookEnSecondValue() {
        #expect(fabric.F["book@en"].value(of: 426_837) == .string("Exodus"))
    }

    @Test func bookEnNodesForGenesis() {
        #expect(fabric.F["book@en"].nodes(for: "Genesis") == [426_836])
    }

    @Test func bookEnMetaContainsLanguage() {
        #expect(fabric.F["book@en"].meta["language"] == "English")
    }

    // MARK: - F: verse (integer feature)

    @Test func verseFirstValue() {
        #expect(fabric.F["verse"].value(of: 428_170) == .int(1))
    }

    @Test func verseIsIntType() {
        let val = fabric.F["verse"].value(of: 428_170)
        #expect(val?.intValue != nil)
        #expect(val?.stringValue == nil)
    }

    @Test func verseMetaContainsDescription() {
        #expect(fabric.F["verse"].meta["description"] == "verse number")
    }

    @Test func verseNodesForOne() {
        // Every chapter starts with verse 1
        #expect(!fabric.F["verse"].nodes(for: 1).isEmpty)
    }

    // MARK: - E: oslots

    @Test func oslotsHasNoValues() {
        #expect(fabric.E["oslots"].hasValues == false)
    }

    @Test func oslotsFromVerseContainsWords() {
        let slots = fabric.E["oslots"].from(428_170)
        #expect(!slots.isEmpty)
        #expect(slots.contains(1))
        #expect(slots.allSatisfy { $0 <= 426_835 })
    }

    @Test func oslotsToSlotReturnsEmpty() {
        // OslotsFeature has no reverse method — use L.up() to find containers.
        #expect(fabric.E["oslots"].to(1).isEmpty)
    }

    @Test func oslotsBidirectionalOnSlotReturnsSelf() {
        // No b(n) on OslotsFeature — falls back to s(n), which returns (n,) for slots.
        #expect(fabric.E["oslots"].bidirectional(1) == [1])
    }

    // MARK: - L: Locality

    @Test func upFromWordToVerse() {
        let verses = fabric.L.up(1, type: "verse")
        #expect(!verses.isEmpty)
        #expect(verses.contains(428_170))
    }

    @Test func upFromWordToBook() {
        #expect(fabric.L.up(1, type: "book") == [426_836])
    }

    @Test func upWithoutTypeFilterReturnsAllContainers() {
        let all = fabric.L.up(1)
        #expect(all.count >= fabric.L.up(1, type: "book").count + fabric.L.up(1, type: "verse").count)
    }

    @Test func downFromVerseToWords() {
        let words = fabric.L.down(428_170, type: "word")
        #expect(!words.isEmpty)
        #expect(words.contains(1))
        #expect(words.allSatisfy { $0 <= 426_835 })
    }

    @Test func downFromBookToChapters() {
        #expect(!fabric.L.down(426_836, type: "chapter").isEmpty)
    }

    @Test func nextVerseExists() {
        let next = fabric.L.next(428_170, type: "verse")
        #expect(!next.isEmpty)
        #expect(next.allSatisfy { $0 > 428_170 })
    }

    @Test func previousVerseOfSecondVerse() {
        #expect(fabric.L.previous(428_171, type: "verse").contains(428_170))
    }

    @Test func intersectingReturnsOverlappingNodes() {
        // L.i() is only defined for structural (non-slot) nodes.
        let result = fabric.L.intersecting(428_170)
        #expect(!result.isEmpty)
        #expect(result.contains(426_836))  // Genesis book overlaps verse 1:1
    }

    // MARK: - T: Text

    @Test func textOfFirstWord() {
        #expect(fabric.T.text(of: 1).contains("ܒܪܫܝܬ"))
    }

    @Test func textOfFirstWordWithOrigFormat() {
        #expect(fabric.T.text(of: 1, format: "text-orig-full").contains("ܒܪܫܝܬ"))
    }

    @Test func textOfNodeSequence() {
        let text = fabric.T.text(of: [1, 2, 3])
        #expect(text.contains("ܒܪܫܝܬ"))
        #expect(text.contains("ܒܪܐ"))
        #expect(text.contains("ܐܠܗܐ"))
    }

    @Test func textOfNodeSequenceEqualsIndividualTexts() {
        #expect(fabric.T.text(of: [1, 2]) == fabric.T.text(of: 1) + fabric.T.text(of: 2))
    }

    @Test func textOfVerseIsNonEmpty() {
        #expect(!fabric.T.text(of: 428_170).isEmpty)
    }

    @Test func sectionFromFirstWordIsGenesisOneOne() {
        let section = fabric.T.section(from: 1)
        #expect(section.count == 3)
        #expect(section[0] == "Genesis")
        #expect(section[1] == "1")
        #expect(section[2] == "1")
    }

    @Test func sectionFromBookNodeHasOneLevel() {
        let section = fabric.T.section(from: 426_836)
        #expect(!section.isEmpty)
        #expect(section[0] == "Genesis")
    }

    @Test func nodeFromSectionReturnsVerseNode() {
        #expect(fabric.T.node(from: ["Genesis", "1", "1"]) == 428_170)
    }

    @Test func nodeFromUnknownSectionIsNil() {
        #expect(fabric.T.node(from: ["NonExistentBook", "1", "1"]) == nil)
    }

    @Test func nodeFromSectionRoundtrips() throws {
        let section = fabric.T.section(from: 1)
        let node = try #require(fabric.T.node(from: section))
        #expect(fabric.T.section(from: node) == section)
    }

    // MARK: - S: Search

    @Test func searchAllBooksReturnsExactCount() {
        #expect(fabric.S.search("book").count == 65)
    }

    @Test func searchEachResultHasOneNode() {
        #expect(fabric.S.search("book").allSatisfy { $0.count == 1 })
    }

    @Test func searchWithLimitCapsResults() {
        #expect(fabric.S.search("word", limit: 10).count == 10)
    }

    @Test func searchByBookNameFindsGenesis() {
        let results = fabric.S.search("book book@en=Genesis")
        #expect(results.count == 1)
        #expect(results[0][0] == 426_836)
    }

    @Test func searchWithNamedSetFiltersResults() {
        let genesisWords: Set<Node> = Set(1 ... 10)
        let results = fabric.S.search("w:myWords", limit: 5, sets: ["myWords": genesisWords])
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.count == 1 && genesisWords.contains($0[0]) })
    }

    @Test func gleanReturnsNonEmptyString() {
        // glean returns "" for book/chapter nodes; verse (sectionTypes[2]) formats as "Genesis 1:1"
        let results = fabric.S.search("verse", limit: 1)
        #expect(!results.isEmpty)
        #expect(!fabric.S.glean(results[0]).isEmpty)
    }

    @Test func gleanContainsSectionInfo() {
        let results = fabric.S.search("verse", limit: 1)
        #expect(fabric.S.glean(results[0]).contains("Genesis"))
    }

    // MARK: - N: Nodes

    @Test func sortWordNodesIsAscending() {
        #expect(fabric.N.sort([3, 1, 2]) == [1, 2, 3])
    }

    @Test func sortIsIdempotent() {
        let nodes = [428_170, 426_836, 1]
        let once = fabric.N.sort(nodes)
        #expect(fabric.N.sort(once) == once)
    }

    @Test func sortEmptyReturnsEmpty() {
        #expect(fabric.N.sort([]).isEmpty)
    }

    @Test func sortSingleNodeReturnsSameNode() {
        #expect(fabric.N.sort([42]) == [42])
    }
}
