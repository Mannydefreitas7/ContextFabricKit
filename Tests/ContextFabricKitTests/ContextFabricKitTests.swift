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
