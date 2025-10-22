import APNSCore
import Vapor
import VaporAPNS

struct ElectricityBindingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let electricityBindings = routes.grouped("electricity-bindings")

        // 新的统一接口
        electricityBindings.post("sync", use: self.syncSchedules)
        electricityBindings.get(":deviceToken", use: self.getSchedules)

        // 旧的接口，保留以兼容旧版本客户端，过三四个版本后可以考虑移除
        electricityBindings.post(use: self.createSchedule)
        electricityBindings.get([":deviceToken", ":id"], use: self.getScheduleById)
        electricityBindings.delete([":deviceToken", ":id"], use: self.cancelScheduleById)
    }

    // MARK: - Sync Schedules

    @Sendable
    func syncSchedules(req: Request) async throws -> HTTPStatus {
        let syncListDTO = try req.content.decode(ElectricityBindingSyncListDTO.self)

        for binding in syncListDTO.bindings {
            try await ElectricityHelper.getInstance().validLocation(campusName: binding.campus, buildingName: binding.building)
            guard binding.scheduleHour >= 0 && binding.scheduleHour < 24 && binding.scheduleMinute >= 0 && binding.scheduleMinute < 60 else {
                throw Abort(.badRequest, reason: "时间格式不正确")
            }
            guard (try? await ElectricityHelper.getInstance().getElectricity(campusName: binding.campus, buildingName: binding.building, room: binding.room)) != nil else {
                throw Abort(.badRequest, reason: "无法获取该宿舍的电量信息")
            }
        }

        // 删除已有绑定
        let existingBindings = try await ElectricityBinding.query(on: req.db)
            .filter(\.$deviceToken, .equal, syncListDTO.deviceToken)
            .all()
        for binding in existingBindings {
            try await ElectricityJob.shared.cancelJob(app: req.application, electricityBinding: binding)
            try await binding.delete(on: req.db)
        }

        // 创建新绑定
        let newBindings = syncListDTO.toModels()
        for binding in newBindings {
            try await binding.save(on: req.db)
            try await ElectricityJob.shared.schedule(app: req.application, electricityBinding: binding)
        }

        return .noContent
    }

    // MARK: - Get Schedules (调试用)

    @Sendable
    func getSchedules(req: Request) async throws -> ElectricityBindingSyncListDTO {
        let deviceToken = try req.parameters.require("deviceToken")

        let bindings = try await ElectricityBinding.query(on: req.db)
            .filter(\.$deviceToken, .equal, deviceToken)
            .all()

        let bindingDTOs = bindings.map { $0.toSyncDTO() }
        guard let studentId = bindings.first?.studentId else {
            throw Abort(.notFound, reason: "未找到对应的电量绑定信息")
        }
        guard let deviceToken = bindings.first?.deviceToken else {
            throw Abort(.notFound, reason: "未找到对应的电量绑定信息")
        }
        return .init(studentId: studentId, deviceToken: deviceToken, bindings: bindingDTOs)
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

        // 验证参数有效性
        try await ElectricityHelper.getInstance().validLocation(campusName: binding.campus, buildingName: binding.building)
        guard binding.scheduleHour >= 0 && binding.scheduleHour < 24 && binding.scheduleMinute >= 0 && binding.scheduleMinute < 60 else {
            throw Abort(.badRequest, reason: "时间格式不正确")
        }
        guard (try? await ElectricityHelper.getInstance().getElectricity(campusName: binding.campus, buildingName: binding.building, room: binding.room)) != nil else {
            throw Abort(.badRequest, reason: "无法获取该宿舍的电量信息")
        }

        // 检查是否已存在相同的绑定
        let existingBinding = try await ElectricityBinding.query(on: req.db)
            .filter(\.$deviceToken, .equal, binding.deviceToken)
            .filter(\.$campus, .equal, binding.campus)
            .filter(\.$building, .equal, binding.building)
            .filter(\.$room, .equal, binding.room)
            .first()
        guard existingBinding == nil else {
            throw Abort(.badRequest, reason: "电量绑定信息已存在")
        }

        // 保存绑定信息并调度任务
        try await binding.save(on: req.db)
        try await ElectricityJob.shared.schedule(app: req.application, electricityBinding: binding)

        return binding.toDTO()
    }
}
