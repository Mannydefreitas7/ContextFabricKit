import Testing
@testable import ContextFabricKit

struct ContextFabricKitTests {

    // MARK: - FeatureValue

    @Test func featureValueStringDescription() {
        #expect(FeatureValue.string("verb").description == "verb")
        #expect(FeatureValue.string("verb").stringValue == "verb")
        #expect(FeatureValue.string("verb").intValue == nil)
    }

    @Test func featureValueIntDescription() {
        #expect(FeatureValue.int(42).description == "42")
        #expect(FeatureValue.int(42).intValue == 42)
        #expect(FeatureValue.int(42).stringValue == nil)
    }

    @Test func featureValueEquality() {
        #expect(FeatureValue.string("noun") == FeatureValue.string("noun"))
        #expect(FeatureValue.int(1) == FeatureValue.int(1))
        #expect(FeatureValue.string("1") != FeatureValue.int(1))
    }

    // MARK: - PythonRuntime

    @Test func runtimeInitializeIsIdempotent() {
        // Repeated calls must not crash. Requires `make bootstrap` to have been run;
        // pass an explicit pythonHome path if running outside an app bundle.
        // PythonRuntime.initialize(pythonHome: "/path/to/Python.framework/Versions/3.13")
    }

    // MARK: - Fabric (requires a real corpus — skipped in CI)
    //
    // To run locally, replace the path with a valid cfabric corpus directory and
    // uncomment the tests below.
    //
    // @Test func fabricLoadsCorpus() async throws {
    //     let fabric = try Fabric(path: "/path/to/corpus")
    //     #expect(fabric.loadedFeatureNames().contains("otype"))
    // }
    //
    // @Test func fabricNodesOfType() async throws {
    //     let fabric = try Fabric(path: "/path/to/corpus")
    //     let words = fabric.nodes(ofType: "word")
    //     #expect(!words.isEmpty)
    // }
}
