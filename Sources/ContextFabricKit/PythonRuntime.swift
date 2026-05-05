import Foundation
import PythonKit

public enum PythonRuntime {
    nonisolated(unsafe) private static var initialized = false

    // Embedded Python version — must match the BeeWare PYTHON_VERSION in the Makefile.
    private static let pythonVersion = "3.13"

    /// Bootstrap the embedded Python interpreter.
    /// Called automatically by `Fabric.init`; call directly only when you need
    /// early initialization or want to supply a custom pythonHome path.
    ///
    /// - Parameter pythonHome: Override the default location of the embedded
    ///   Python.framework (e.g. for unit tests). Defaults to
    ///   `<AppBundle>/Contents/Frameworks/Python.framework/Versions/<version>`.
    public static func initialize(pythonHome: String? = nil) {
        guard !initialized else { return }
        let home = pythonHome ?? defaultPythonHome()
        let lib = "\(home)/lib/python\(pythonVersion)"
        setenv("PYTHONHOME", home, 1)
        setenv("PYTHONPATH", [lib, "\(lib)/lib-dynload", "\(lib)/site-packages"].joined(separator: ":"), 1)
        initialized = true
    }

    private static func defaultPythonHome() -> String {
        let path = "\(Bundle.main.bundlePath)/Contents/Frameworks/Python.framework/Versions/\(pythonVersion)"
        guard FileManager.default.fileExists(atPath: path) else {
            fatalError("""
                ContextFabricKit: Python.framework not found at \(path).
                Ensure Python.xcframework is embedded in your app target.
                For tests, call PythonRuntime.initialize(pythonHome:) with an explicit path.
                """)
        }
        return path
    }
}
