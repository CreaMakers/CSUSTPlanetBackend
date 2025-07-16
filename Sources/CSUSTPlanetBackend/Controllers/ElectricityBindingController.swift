import APNSCore
import Vapor

struct ElectricityBindingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let electricityBindings = routes.grouped("electricity-bindings")

        electricityBindings.post(use: self.create)
        electricityBindings.get(":deviceToken", use: self.getSchedules)
    }

    @Sendable
    func getSchedules(req: Request) async throws -> [ElectricityBindingDTO] {
        let deviceToken = try req.parameters.require("deviceToken")
        let bindings = try await ElectricityBinding.query(on: req.db)
            .filter(\.$deviceToken, .equal, deviceToken)
            .all()

        return bindings.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> HTTPStatus {
        let binding = try req.content.decode(ElectricityBindingDTO.self).toModel()

        if !(await ElectricityHelper.shared.validLocation(
            campusName: binding.campus, buildingName: binding.building))
        {
            throw Abort(.badRequest, reason: "Invalid location")
        }

        guard binding.scheduleHour >= 0 && binding.scheduleHour < 24 else {
            throw Abort(.badRequest, reason: "Invalid schedule hour")
        }

        guard binding.scheduleMinute >= 0 && binding.scheduleMinute < 60 else {
            throw Abort(.badRequest, reason: "Invalid schedule minute")
        }

        guard
            (try? await ElectricityHelper.shared.getElectricity(
                campusName: binding.campus,
                buildingName: binding.building,
                room: binding.room
            )) != nil
        else {
            throw Abort(.badRequest, reason: "Invalid electricity data")
        }

        let existingBinding = try await ElectricityBinding.query(on: req.db)
            .filter(\.$studentId, .equal, binding.studentId)
            .filter(\.$deviceToken, .equal, binding.deviceToken)
            .filter(\.$campus, .equal, binding.campus)
            .filter(\.$building, .equal, binding.building)
            .filter(\.$room, .equal, binding.room)
            .first()

        guard existingBinding == nil else {
            throw Abort(.badRequest, reason: "Binding already exists for this device")
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

        try await ElectricityJob.shared.schedule(app: req.application, electricityBinding: binding)

        return .created
    }
}
