import Fluent

final class ElectricityBinding: Model, @unchecked Sendable {
    static let schema = "electricity_bindings"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "student_id")
    var studentId: String

    @Field(key: "device_token")
    var deviceToken: String

    @Field(key: "campus")
    var campus: String

    @Field(key: "building")
    var building: String

    @Field(key: "room")
    var room: String

    @Field(key: "schedule_time")
    var scheduleTime: String

    init() {}

    init(
        id: UUID? = nil, studentId: String, deviceToken: String, campus: String, building: String,
        room: String, scheduleTime: String
    ) {
        self.id = id
        self.studentId = studentId
        self.deviceToken = deviceToken
        self.campus = campus
        self.building = building
        self.room = room
        self.scheduleTime = scheduleTime
    }
}
