import APNS
import APNSCore
import Fluent
import FluentSQLiteDriver
import NIOSSL
import Vapor
import VaporAPNS

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(CreateElectricityBinding())

    guard let keyIdentifier = Environment.get("APNS_KEY_IDENTIFIER"),
        let teamIdentifier = Environment.get("APNS_TEAM_IDENTIFIER"),
        let privateKeyPath = Environment.get("APNS_PRIVATE_KEY_PATH")
    else {
        fatalError("Missing APNS configuration")
    }

    let privateKeyData = try Data(contentsOf: URL(fileURLWithPath: privateKeyPath))
    let privateKeyString = String(data: privateKeyData, encoding: .utf8)!
    let privateKey = try P256.Signing.PrivateKey(pemRepresentation: privateKeyString)

    let apnsConfig = APNSClientConfiguration(
        authenticationMethod: .jwt(
            privateKey: privateKey,
            keyIdentifier: keyIdentifier,
            teamIdentifier: teamIdentifier
        ),
        environment: .development)

    await app.apns.containers.use(
        apnsConfig,
        eventLoopGroupProvider: .shared(app.eventLoopGroup),
        responseDecoder: JSONDecoder(),
        requestEncoder: JSONEncoder(),
        as: .default
    )

    // register routes
    try await routes(app)
}
