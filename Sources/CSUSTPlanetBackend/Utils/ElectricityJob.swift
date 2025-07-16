import APNSCore
import NIOCronScheduler
import Vapor

actor ElectricityJob {
    static let shared = ElectricityJob()
    private init() {}

    private var jobs: [String: NIOCronJob] = [:]

    func beijingTimeToCron(minute: Int, hour: Int) -> String {
        var utcHour = hour - 8

        if utcHour < 0 {
            utcHour += 24
        }

        return "\(minute) \(utcHour) * * *"
    }

    func cancelJob(electricityBinding: ElectricityBinding) throws {
        guard let id = electricityBinding.id?.uuidString else {
            throw Abort(.badRequest, reason: "ElectricityBinding ID is missing")
        }
        if let job = jobs[id] {
            job.cancel()
            jobs.removeValue(forKey: id)
        }
    }

    func schedule(app: Application, electricityBinding: ElectricityBinding) throws {
        guard let id = electricityBinding.id?.uuidString else {
            throw Abort(.badRequest, reason: "ElectricityBinding ID is missing")
        }

        let cronExpression = beijingTimeToCron(
            minute: electricityBinding.scheduleMinute,
            hour: electricityBinding.scheduleHour
        )
        let job = try app.cron.schedule(cronExpression) {
            Task {
                do {
                    let electricity = try await ElectricityHelper.shared.getElectricity(
                        campusName: electricityBinding.campus,
                        buildingName: electricityBinding.building,
                        room: electricityBinding.room
                    )
                    let alert = APNSAlertNotification(
                        alert: .init(
                            title: .raw("电量定时查询结果"),
                            body: .raw("您的宿舍\(electricityBinding.room)当前电量为 \(electricity) 度")
                        ),
                        expiration: .immediately,
                        priority: .immediately,
                        topic: "com.zhelearn.CSUSTPlanet",
                        badge: 0
                    )
                    try await app.apns.client.sendAlertNotification(
                        alert, deviceToken: electricityBinding.deviceToken)
                } catch {
                    app.logger.error("Failed to send electricity notification: \(error)")
                }
            }
        }
        jobs[id] = job
    }
}
