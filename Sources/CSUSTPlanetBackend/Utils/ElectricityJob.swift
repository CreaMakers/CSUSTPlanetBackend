import APNSCore
import NIOCronScheduler
import Vapor
import VaporAPNS

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

  func cancelJob(app: Application, electricityBinding: ElectricityBinding) throws {
    guard let id = electricityBinding.id?.uuidString else {
      throw Abort(.badRequest, reason: "ElectricityBinding ID is missing")
    }
    if let job = jobs[id] {
      job.cancel()
      jobs.removeValue(forKey: id)
    }
    app.logger.info("Cancelled electricity job for \(electricityBinding.room) with ID \(id)")
  }

  func schedule(app: Application, electricityBinding: ElectricityBinding) throws {
    guard let id = electricityBinding.id?.uuidString else {
      throw Abort(.badRequest, reason: "ElectricityBinding ID is missing")
    }

    let cronExpression = beijingTimeToCron(minute: electricityBinding.scheduleMinute, hour: electricityBinding.scheduleHour)
    let job = try app.cron.schedule(cronExpression) {
      Task {
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
          let environment: APNSContainers.ID = electricityBinding.isDebug ? .development : .production
          try await app.apns.client(environment).sendAlertNotification(alert, deviceToken: electricityBinding.deviceToken)
          app.logger.info("Electricity notification sent successfully for \(electricityBinding.room)")
        } catch let apnsError as APNSError {
          switch apnsError.reason {
          case .badDeviceToken, .unregistered, .deviceTokenNotForTopic:
            app.logger.error("Invalid device token: \(electricityBinding.deviceToken)")
            try? await ElectricityJob.shared.cancelJob(app: app, electricityBinding: electricityBinding)
            try? await electricityBinding.delete(on: app.db)
          default:
            app.logger.error("APNS error: \(apnsError)")
          }
        } catch {
          app.logger.error("Failed to send electricity notification: \(error)")
        }
      }
    }
    jobs[id] = job
    app.logger.info("Scheduled electricity job for \(electricityBinding.room) with ID \(id)")
  }
}
