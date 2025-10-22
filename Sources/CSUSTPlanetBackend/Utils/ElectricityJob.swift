import APNSCore
import NIOCronScheduler
import Vapor
import VaporAPNS

actor ElectricityJob {
    static let shared = ElectricityJob()
    private init() {}

    private var jobs: [String: NIOCronJob] = [:]

    private func beijingTimeToCron(minute: Int, hour: Int) -> String {
        var utcHour = hour - 8

        if utcHour < 0 {
            utcHour += 24
        }

        return "\(minute) \(utcHour) * * *"
    }

    // MARK: - Cancel Job

    func cancelJob(app: Application, electricityBinding: ElectricityBinding) throws {
        guard let id = electricityBinding.id?.uuidString else {
            throw Abort(.badRequest, reason: "缺少电量绑定ID")
        }
        if let job = jobs[id] {
            job.cancel()
            jobs.removeValue(forKey: id)
        }
        app.logger.info("取消电量定时任务，宿舍：\(electricityBinding.room)")
    }

    // MARK: - Schedule Job

    func scheduleJob(app: Application, electricityBinding: ElectricityBinding) throws {
        guard let id = electricityBinding.id?.uuidString else {
            throw Abort(.badRequest, reason: "缺少电量绑定ID")
        }

        let cronExpression = beijingTimeToCron(minute: electricityBinding.scheduleMinute, hour: electricityBinding.scheduleHour)

        // 调度内容
        let job = try app.cron.schedule(cronExpression) {
            Task {
                app.logger.info("开始执行电量查询任务，宿舍：\(electricityBinding.room)")
                do {
                    let electricity = try await ElectricityHelper.getInstance().getElectricity(
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
                    try await app.apns.client.sendAlertNotification(alert, deviceToken: electricityBinding.deviceToken)
                    app.logger.info("电量查询通知发送成功，宿舍：\(electricityBinding.room)，电量：\(electricity) 度")
                } catch let apnsError as APNSError {
                    switch apnsError.reason {
                    case .badDeviceToken, .unregistered, .deviceTokenNotForTopic:
                        app.logger.error("设备令牌无效，取消电量定时任务，宿舍：\(electricityBinding.room)")
                        try? await ElectricityJob.shared.cancelJob(app: app, electricityBinding: electricityBinding)
                        try? await electricityBinding.delete(on: app.db)
                    default:
                        app.logger.error("APNS错误: \(apnsError)")
                    }
                } catch {
                    app.logger.error("电量查询或通知发送失败: \(error)")
                }
            }
        }
        jobs[id] = job
        app.logger.info("配置调度电量查询任务，宿舍：\(electricityBinding.room)，时间：\(electricityBinding.scheduleHour):\(electricityBinding.scheduleMinute)")
    }
}
