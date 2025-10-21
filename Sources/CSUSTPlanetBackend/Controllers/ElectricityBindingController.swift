import APNSCore
import Vapor
import VaporAPNS

struct ElectricityBindingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let electricityBindings = routes.grouped("electricity-bindings")

        electricityBindings.post([":deviceToken", "sync"], use: self.syncSchedules)

        electricityBindings.post(use: self.createSchedule)
        electricityBindings.get([":deviceToken", ":id"], use: self.getScheduleById)
        electricityBindings.delete([":deviceToken", ":id"], use: self.cancelScheduleById)
    }

    // MARK: - Sync Schedules

    @Sendable
    func syncSchedules(req: Request) async throws -> [ElectricityBindingDTO] {
        return []
    }

    // MARK: - Cancel Schedule By ID

    @Sendable
    func cancelScheduleById(req: Request) async throws -> HTTPStatus {
        let deviceToken = try req.parameters.require("deviceToken")
        let id = try req.parameters.require("id")

        guard let uuid = UUID(uuidString: id) else {
            throw Abort(.badRequest, reason: "ID格式不正确")
        }

        let binding = try await ElectricityBinding.query(on: req.db)
            .filter(\.$deviceToken, .equal, deviceToken)
            .filter(\.$id, .equal, uuid)
            .first()
        guard let binding = binding else {
            throw Abort(.notFound, reason: "未找到对应的电量绑定信息")
        }

        try await ElectricityJob.shared.cancelJob(app: req.application, electricityBinding: binding)
        try await binding.delete(on: req.db)

        return .noContent
    }

    // MARK: - Get Schedule By ID

    @Sendable
    func getScheduleById(req: Request) async throws -> ElectricityBindingDTO {
        let deviceToken = try req.parameters.require("deviceToken")
        let id = try req.parameters.require("id")

        guard let uuid = UUID(uuidString: id) else {
            throw Abort(.badRequest, reason: "ID格式不正确")
        }

        let binding = try await ElectricityBinding.query(on: req.db)
            .filter(\.$deviceToken, .equal, deviceToken)
            .filter(\.$id, .equal, uuid)
            .first()
        guard let binding = binding else {
            throw Abort(.notFound, reason: "未找到对应的电量绑定信息")
        }

        return binding.toDTO()
    }

    // MARK: - Create Schedule

    @Sendable
    func createSchedule(req: Request) async throws -> ElectricityBindingDTO {
        let binding = try req.content.decode(ElectricityBindingDTO.self).toModel()

        try await ElectricityHelper.getInstance().validLocation(campusName: binding.campus, buildingName: binding.building)

        guard binding.scheduleHour >= 0 && binding.scheduleHour < 24 else {
            throw Abort(.badRequest, reason: "小时格式不正确")
        }

        guard binding.scheduleMinute >= 0 && binding.scheduleMinute < 60 else {
            throw Abort(.badRequest, reason: "分钟格式不正确")
        }

        guard (try? await ElectricityHelper.getInstance().getElectricity(campusName: binding.campus, buildingName: binding.building, room: binding.room)) != nil else {
            throw Abort(.badRequest, reason: "无法获取该宿舍的电量信息")
        }

        let existingBinding = try await ElectricityBinding.query(on: req.db)
            .filter(\.$deviceToken, .equal, binding.deviceToken)
            .filter(\.$campus, .equal, binding.campus)
            .filter(\.$building, .equal, binding.building)
            .filter(\.$room, .equal, binding.room)
            .first()

        guard existingBinding == nil else {
            throw Abort(.badRequest, reason: "电量绑定信息已存在")
        }

        let alert = APNSAlertNotification(
            alert: .init(title: .raw("电量定时查询设置成功"), body: .raw("您的宿舍\(binding.room)已成功绑定定时电量查询")),
            expiration: .immediately,
            priority: .immediately,
            topic: "com.zhelearn.CSUSTPlanet",
            badge: 0
        )

        guard (try? await req.apns.client.sendAlertNotification(alert, deviceToken: binding.deviceToken)) != nil else {
            throw Abort(.badRequest, reason: "无法发送测试通知")
        }

        try await binding.save(on: req.db)

        try await ElectricityJob.shared.schedule(app: req.application, electricityBinding: binding)

        return binding.toDTO()
    }
}
