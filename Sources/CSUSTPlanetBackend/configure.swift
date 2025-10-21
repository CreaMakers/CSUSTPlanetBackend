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

    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    try await setupDatabase(app)
    try await setupAPNS(app)
    try await setupBindings(app)

    // register routes
    try await routes(app)
}

private func setupDatabase(_ app: Application) async throws {
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    app.migrations.add(CreateElectricityBinding())
    try await app.autoMigrate()
}

// MARK: - APNS Setup

private func setupAPNS(_ app: Application) async throws {
    guard let keyIdentifier = Environment.get("APNS_KEY_IDENTIFIER"),
        let privateKeyPath = Environment.get("APNS_PRIVATE_KEY_PATH"),
        let teamIdentifier = Environment.get("APNS_TEAM_IDENTIFIER")
    else {
        fatalError("缺少 APNS 配置环境变量")
    }

    guard let apnsEnvironmentString = Environment.get("APNS_ENVIRONMENT"),
        apnsEnvironmentString == "production" || apnsEnvironmentString == "development"
    else {
        fatalError("缺少 APNS_ENVIRONMENT 环境变量")
    }
    let apnsEnvironment: APNSEnvironment = apnsEnvironmentString == "production" ? .production : .development

    guard let privateKeyString = String(data: try Data(contentsOf: URL(fileURLWithPath: privateKeyPath)), encoding: .utf8) else {
        fatalError("无法读取 APNS 私钥文件")
    }

    let apnsConfigProd = APNSClientConfiguration(
        authenticationMethod: .jwt(
            privateKey: try P256.Signing.PrivateKey(pemRepresentation: privateKeyString),
            keyIdentifier: keyIdentifier,
            teamIdentifier: teamIdentifier
        ),
        environment: apnsEnvironment
    )
    await app.apns.containers.use(
        apnsConfigProd,
        eventLoopGroupProvider: .shared(app.eventLoopGroup),
        responseDecoder: JSONDecoder(),
        requestEncoder: JSONEncoder(),
        as: .default
    )
}

// MARK: - Bindings Setup

private func setupBindings(_ app: Application) async throws {
    let bindings = try await ElectricityBinding.query(on: app.db).all()
    for binding in bindings {
        try await ElectricityJob.shared.schedule(app: app, electricityBinding: binding)
    }
}
