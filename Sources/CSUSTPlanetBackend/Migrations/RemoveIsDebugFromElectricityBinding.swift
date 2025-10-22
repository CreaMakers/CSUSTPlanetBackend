import Fluent

struct RemoveIsDebugFromElectricityBinding: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("electricity_bindings")
            .deleteField("is_debug")
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("electricity_bindings")
            .field("is_debug", .bool, .required, .sql(.default(false)))
            .update()
    }
}
