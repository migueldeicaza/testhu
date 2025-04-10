import Hummingbird
import HummingbirdCore
import HummingbirdTLS
import Logging
import NIOSSL
import HummingbirdWSCompression
import HummingbirdWebSocket

/// Application arguments protocol
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
    var certPath: String { get }
    var keyPath: String { get }
}

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "testhu")
        logger.logLevel = .trace
        return logger
    }()

    let wsRouter = Router(context: BasicWebSocketRequestContext.self)

    wsRouter.middlewares.add(LogRequestsMiddleware(.debug))

    wsRouter.ws("proxy") { request, _ in
        print("Reachrd - upgrading")
        return .upgrade([:])
    } onUpgrade: { (inbound: WebSocketInboundStream, outbound: WebSocketOutboundWriter, context) in
        try await outbound.write(.text("HELLO: Server to client"))

        for try await input in inbound.messages(maxSize: 1_000_000) {
            print("Server received: \(input)")
            // Only process one message, and exit
            break
        }
        try await outbound.write(.text("Server to client"))

    }
    // Load SSL certificates
    let certificateChain = try NIOSSLCertificate.fromPEMFile(arguments.certPath)
    let privateKey = try NIOSSLPrivateKey(file: arguments.keyPath, format: .pem)

    // Create TLS configuration
    var tlsConfiguration = TLSConfiguration.makeServerConfiguration(
        certificateChain: certificateChain.map { .certificate($0) },
        privateKey: .privateKey(privateKey)
    )
    tlsConfiguration.certificateVerification = .none

    let router = buildRouter()
    let app = try Application(
        router: router,
        //server: .tls(tlsConfiguration: tlsConfiguration),
        server: .tls(
            .http1WebSocketUpgrade(
                webSocketRouter: wsRouter,
                configuration: .init(extensions: [.perMessageDeflate()])
            ),
            tlsConfiguration: tlsConfiguration),
        configuration: .init(
            address: .hostname("localhost", port: arguments.port)
        ),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter() -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
    }
    // Add default endpoint
    router.get("/") { _,_ in
        return "Hello!"
    }
    return router
}
