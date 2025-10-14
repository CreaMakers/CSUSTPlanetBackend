import APNSCore
import Vapor
import VaporAPNS

struct ElectricityBindingController: RouteCollection {
  func boot(routes: any RoutesBuilder) throws {
    let electricityBindings = routes.grouped("electricity-bindings")

    electricityBindings.post(use: self.createSchedule)
    electricityBindings.get(":deviceToken", use: self.getSchedules)
    electricityBindings.delete(":deviceToken", use: self.cancelSchedules)
    electricityBindings.get([":deviceToken", ":id"], use: self.getScheduleById)
    electricityBindings.delete([":deviceToken", ":id"], use: self.cancelScheduleById)
  }

  @Sendable
  func cancelSchedules(req: Request) async throws -> [ElectricityBindingDTO] {
    let deviceToken = try req.parameters.require("deviceToken")

    let bindings = try await ElectricityBinding.query(on: req.db)
      .filter(\.$deviceToken, .equal, deviceToken)
      .all()

    for binding in bindings {
      try await ElectricityJob.shared.cancelJob(app: req.application, electricityBinding: binding)
      try await binding.delete(on: req.db)
    }

    return bindings.map { $0.toDTO() }
  }

  @Sendable
  func cancelScheduleById(req: Request) async throws -> [ElectricityBindingDTO] {
    let deviceToken = try req.parameters.require("deviceToken")
    let id = try req.parameters.require("id")

    guard let uuid = UUID(uuidString: id) else {
      throw Abort(.badRequest, reason: "Invalid UUID format for ID")
    }

    let binding = try await ElectricityBinding.query(on: req.db)
      .filter(\.$deviceToken, .equal, deviceToken)
      .filter(\.$id, .equal, uuid)
      .first()
    guard let binding = binding else {
      throw Abort(.notFound, reason: "ElectricityBinding not found")
    }

    try await ElectricityJob.shared.cancelJob(app: req.application, electricityBinding: binding)
    try await binding.delete(on: req.db)

    return try await getSchedules(req: req)
  }

  @Sendable
  func getScheduleById(req: Request) async throws -> ElectricityBindingDTO {
    let deviceToken = try req.parameters.require("deviceToken")
    let id = try req.parameters.require("id")

    guard let uuid = UUID(uuidString: id) else {
      throw Abort(.badRequest, reason: "Invalid UUID format for ID")
    }

    let binding = try await ElectricityBinding.query(on: req.db)
      .filter(\.$deviceToken, .equal, deviceToken)
      .filter(\.$id, .equal, uuid)
      .first()
    guard let binding = binding else {
      throw Abort(.notFound, reason: "ElectricityBinding not found")
    }

    return binding.toDTO()
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
  func createSchedule(req: Request) async throws -> ElectricityBindingDTO {
    let binding = try req.content.decode(ElectricityBindingDTO.self).toModel()

    try await ElectricityHelper.getInstance().validLocation(campusName: binding.campus, buildingName: binding.building)

    guard binding.scheduleHour >= 0 && binding.scheduleHour < 24 else {
      throw Abort(.badRequest, reason: "Invalid schedule hour")
    }

    guard binding.scheduleMinute >= 0 && binding.scheduleMinute < 60 else {
      throw Abort(.badRequest, reason: "Invalid schedule minute")
    }

    guard (try? await ElectricityHelper.getInstance().getElectricity(campusName: binding.campus, buildingName: binding.building, room: binding.room)) != nil else {
      throw Abort(.badRequest, reason: "Invalid electricity data")
    }

    let existingBinding = try await ElectricityBinding.query(on: req.db)
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

    let environment: APNSContainers.ID = binding.isDebug ? .development : .production

    guard (try? await req.apns.client(environment).sendAlertNotification(alert, deviceToken: binding.deviceToken)) != nil else {
      throw Abort(.badRequest, reason: "Device token is invalid or APNS failed")
    }

    try await binding.save(on: req.db)

    try await ElectricityJob.shared.schedule(app: req.application, electricityBinding: binding)

    return binding.toDTO()
  }
}
