import Testing
@testable import ContextFabricKit

struct ContextFabricKitTests {

    @Test func runtimeInitializesOnce() {
        // Verify repeated calls to initialize() are idempotent and don't crash.
        // Requires `make bootstrap` to have been run for the stdlib to be present.
        PythonRuntime.initialize()
        PythonRuntime.initialize()
    }
}
