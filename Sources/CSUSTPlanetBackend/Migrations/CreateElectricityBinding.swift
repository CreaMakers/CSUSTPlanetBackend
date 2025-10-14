import Fluent

struct CreateElectricityBinding: AsyncMigration {
  func prepare(on database: any Database) async throws {
    try await database.schema("electricity_bindings")
      .id()
      .field("student_id", .string, .required)
      .field("device_token", .string, .required)
      .field("is_debug", .bool, .required)
      .field("campus", .string, .required)
      .field("building", .string, .required)
      .field("room", .string, .required)
      .field("schedule_hour", .int, .required)
      .field("schedule_minute", .int, .required)
      .unique(on: "device_token", "campus", "building", "room")
      .create()
  }

  func revert(on database: any Database) async throws {
    try await database.schema("electricity_bindings").delete()
  }
}
