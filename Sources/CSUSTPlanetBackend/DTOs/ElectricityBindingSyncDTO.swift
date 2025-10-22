import Fluent
import Vapor

struct ElectricityBindingSyncListDTO: Content {
    var studentId: String
    var deviceToken: String

    var bindings: [ElectricityBindingSyncDTO]

    func toModels() -> [ElectricityBinding] {
        return bindings.map { dto in
            .init(
                studentId: studentId,
                deviceToken: deviceToken,
                campus: dto.campus,
                building: dto.building,
                room: dto.room,
                scheduleHour: dto.scheduleHour,
                scheduleMinute: dto.scheduleMinute
            )
        }
    }
}

struct ElectricityBindingSyncDTO: Content {
    var campus: String
    var building: String
    var room: String
    var scheduleHour: Int
    var scheduleMinute: Int
}
