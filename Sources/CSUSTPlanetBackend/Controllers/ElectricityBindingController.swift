import Vapor

struct ElectricityBindingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let electricityBindings = routes.grouped("electricity-bindings")

        electricityBindings.post(use: self.create)
    }

    @Sendable
    func create(req: Request) async throws -> HTTPStatus {
        let binding = try req.content.decode(ElectricityBindingDTO.self).toModel()

        try await binding.save(on: req.db)

        return .created
    }
}
