import Vapor

final class ElectricityBindingController: RouteCollection, Sendable {
    private let electricityHelper: ElectricityHelper

    init() async {
        if let helper = await ElectricityHelper.create() {
            self.electricityHelper = helper
        } else {
            fatalError("Failed to create ElectricityHelper")
        }
    }

    func boot(routes: any RoutesBuilder) throws {
        let electricityBindings = routes.grouped("electricity-bindings")

        electricityBindings.post(use: self.create)
    }

    @Sendable
    func create(req: Request) async throws -> HTTPStatus {
        let binding = try req.content.decode(ElectricityBindingDTO.self).toModel()

        if !(await electricityHelper.validLocation(
            campusName: binding.campus, buildingName: binding.building))
        {
            throw Abort(.badRequest, reason: "Invalid location")
        }

        guard
            (try? await electricityHelper.getElectricity(
                campusName: binding.campus,
                buildingName: binding.building,
                room: binding.room
            )) != nil
        else {
            throw Abort(.badRequest, reason: "Invalid electricity data")
        }

        try await binding.save(on: req.db)

        return .created
    }
}
