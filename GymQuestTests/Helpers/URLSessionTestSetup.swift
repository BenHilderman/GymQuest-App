import Foundation

/// Registers/unregisters MockURLProtocol globally so that URLSession.shared
/// calls are intercepted without any dependency injection in source code.
enum URLSessionTestSetup {

    /// Register MockURLProtocol to intercept all URLSession.shared requests
    static func install() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    /// Unregister MockURLProtocol and clear all stubs
    static func uninstall() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.stubbedResponses.removeAll()
        MockURLProtocol.requestHandler = nil
    }
}
