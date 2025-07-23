import APNS
import APNSCore
import Fluent
import FluentSQLiteDriver
import NIOSSL
import Vapor
import VaporAPNS
import VaporCron

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(CreateElectricityBinding())

    try await app.autoMigrate()

    let fileMiddleware = FileMiddleware(publicDirectory: app.directory.publicDirectory)
    app.middleware.use(fileMiddleware)

    guard let teamIdentifier = Environment.get("APNS_TEAM_IDENTIFIER") else {
        fatalError("Missing APNS Team Identifier")
    }

    guard let sandboxKeyIdentifier = Environment.get("SANDBOX_APNS_KEY_IDENTIFIER"),
        let sandboxPrivateKeyPath = Environment.get("SANDBOX_APNS_PRIVATE_KEY_PATH")
    else {
        fatalError("Missing Sandbox APNS configuration")
    }

    guard let prodKeyIdentifier = Environment.get("PRODUCTION_APNS_KEY_IDENTIFIER"),
        let prodPrivateKeyPath = Environment.get("PRODUCTION_APNS_PRIVATE_KEY_PATH")
    else {
        fatalError("Missing Production APNS configuration")
    }

    let sandboxPrivateKeyData = try Data(contentsOf: URL(fileURLWithPath: sandboxPrivateKeyPath))
    let sandboxPrivateKeyString = String(data: sandboxPrivateKeyData, encoding: .utf8)!
    let sandboxPrivateKey = try P256.Signing.PrivateKey(pemRepresentation: sandboxPrivateKeyString)

    let prodPrivateKeyData = try Data(contentsOf: URL(fileURLWithPath: prodPrivateKeyPath))
    let prodPrivateKeyString = String(data: prodPrivateKeyData, encoding: .utf8)!
    let prodPrivateKey = try P256.Signing.PrivateKey(pemRepresentation: prodPrivateKeyString)

    let apnsConfigDev = APNSClientConfiguration(
        authenticationMethod: .jwt(
            privateKey: sandboxPrivateKey,
            keyIdentifier: sandboxKeyIdentifier,
            teamIdentifier: teamIdentifier
        ),
        environment: .development
    )
    await app.apns.containers.use(
        apnsConfigDev,
        eventLoopGroupProvider: .shared(app.eventLoopGroup),
        responseDecoder: JSONDecoder(),
        requestEncoder: JSONEncoder(),
        as: .development
    )

    let apnsConfigProd = APNSClientConfiguration(
        authenticationMethod: .jwt(
            privateKey: prodPrivateKey,
            keyIdentifier: prodKeyIdentifier,
            teamIdentifier: teamIdentifier
        ),
        environment: .production
    )
    await app.apns.containers.use(
        apnsConfigProd,
        eventLoopGroupProvider: .shared(app.eventLoopGroup),
        responseDecoder: JSONDecoder(),
        requestEncoder: JSONEncoder(),
        as: .production
    )

    let bindings = try await ElectricityBinding.query(on: app.db).all()
    for binding in bindings {
        try await ElectricityJob.shared.schedule(app: app, electricityBinding: binding)
    }

    // register routes
    try await routes(app)
}
