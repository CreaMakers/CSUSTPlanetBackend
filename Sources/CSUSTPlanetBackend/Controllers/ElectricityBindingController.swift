import APNSCore
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

        let alert = APNSAlertNotification(
            alert: .init(title: .raw("电量定时查询设置成功"), body: .raw("您的宿舍\(binding.room)已成功绑定定时电量查询")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.zhelearn.CSUSTPlanet",
            badge: 0
        )

        guard
            (try? await req.apns.client.sendAlertNotification(
                alert, deviceToken: binding.deviceToken)) != nil
        else {
            throw Abort(.badRequest, reason: "Device token is invalid or APNS failed")
        }

        try await binding.save(on: req.db)

        return .created
    }
}
