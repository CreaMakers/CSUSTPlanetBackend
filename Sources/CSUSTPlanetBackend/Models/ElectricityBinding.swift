import Fluent

final class ElectricityBinding: Model, @unchecked Sendable {
    static let schema = "electricity_bindings"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "student_id")
    var studentId: String

    @Field(key: "device_token")
    var deviceToken: String

    @Field(key: "is_debug")
    var isDebug: Bool

    @Field(key: "campus")
    var campus: String

    @Field(key: "building")
    var building: String

    @Field(key: "room")
    var room: String

    @Field(key: "schedule_hour")
    var scheduleHour: Int

    @Field(key: "schedule_minute")
    var scheduleMinute: Int

    init() {}

    init(
        id: UUID? = nil, studentId: String, deviceToken: String, isDebug: Bool, campus: String,
        building: String,
        room: String, scheduleHour: Int, scheduleMinute: Int
    ) {
        self.id = id
        self.studentId = studentId
        self.deviceToken = deviceToken
        self.isDebug = isDebug
        self.campus = campus
        self.building = building
        self.room = room
        self.scheduleHour = scheduleHour
        self.scheduleMinute = scheduleMinute
    }

    func toDTO() -> ElectricityBindingDTO {
        .init(
            id: self.id,
            studentId: self.studentId,
            deviceToken: self.deviceToken,
            isDebug: self.isDebug,
            campus: self.campus,
            building: self.building,
            room: self.room,
            scheduleHour: self.scheduleHour,
            scheduleMinute: self.scheduleMinute
        )
    }
}
