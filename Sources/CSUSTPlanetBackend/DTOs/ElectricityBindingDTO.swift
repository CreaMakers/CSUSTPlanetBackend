import Fluent
import Vapor

struct ElectricityBindingDTO: Content {
    var studentId: String
    var deviceToken: String
    var campus: String
    var building: String
    var room: String
    var scheduleTime: String

    func toModel() -> ElectricityBinding {
        return ElectricityBinding(
            studentId: studentId,
            deviceToken: deviceToken,
            campus: campus,
            building: building,
            room: room,
            scheduleTime: scheduleTime
        )
    }
}
