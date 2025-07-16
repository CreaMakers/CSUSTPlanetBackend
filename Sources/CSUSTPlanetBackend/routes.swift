import Fluent
import Vapor

func routes(_ app: Application) async throws {
    try app.register(collection: await ElectricityBindingController())
}
