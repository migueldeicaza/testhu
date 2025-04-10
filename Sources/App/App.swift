import ArgumentParser
import Hummingbird
import Logging
import NIOSSL
import HummingbirdWebSocket
import Logging
import ServiceLifecycle
import HummingbirdWSClient

@main
struct AppCommand: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8443  // Changed to default HTTPS port

    @Option(name: .shortAndLong)
    var logLevel: Logger.Level?
    
    @Option(name: .shortAndLong)
    var certPath: String = "/Users/miguel/cvs/testhu/cert.pem"

    @Option(name: .shortAndLong)
    var keyPath: String = "/Users/miguel/cvs/testhu/key.pem"

    @Flag
    var client: Bool = false

    func run() async throws {
        if client {

            // Create TLS configuration
            var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
            tlsConfiguration.certificateVerification = .none

            do {
                //let url = "https://echo.websocket.org/"
                let url = "wss://localhost:8443/proxy/"
                _ = try await WebSocketClient.connect(url: url, tlsConfiguration: tlsConfiguration, logger: Logger(label: "client")) { inbound, outbound, context in
                    try await outbound.write(.text("First of Two"))
                    for try await input in inbound.messages(maxSize: 1_000_000) {
                        print(input)
                    }
                }
            } catch {
                print("Client failed \(error)")
            }
            print("Client call completed")
        } else {
            let app = try await buildApplication(self)
            try await app.runService()
        }
    }
}

/// Extend `Logger.Level` so it can be used as an argument
#if hasFeature(RetroactiveAttribute)
    extension Logger.Level: @retroactive ExpressibleByArgument {}
#else
    extension Logger.Level: ExpressibleByArgument {}
#endif
