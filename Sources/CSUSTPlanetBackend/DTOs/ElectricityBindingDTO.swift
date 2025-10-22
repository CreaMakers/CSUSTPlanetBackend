import Fluent
import Vapor

struct ElectricityBindingDTO: Content {
    var id: UUID?
    var studentId: String
    var deviceToken: String
    var campus: String
    var building: String
    var room: String
    var scheduleHour: Int
    var scheduleMinute: Int

    func toModel() -> ElectricityBinding {
        .init(
            studentId: studentId,
            deviceToken: deviceToken,
            campus: campus,
            building: building,
            room: room,
            scheduleHour: scheduleHour,
            scheduleMinute: scheduleMinute
        )
    }
}
