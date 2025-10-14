import CSUSTKit

enum ElectricityHelperError: Error {
  case invalidCampus
  case buildingNotFound
}

actor ElectricityHelper {
  private let campusCardHelper = CampusCardHelper()
  private var buildings: [Campus: [String: Building]] = [:]

  private static let shared: ElectricityHelper = ElectricityHelper()
  private lazy var initializationTask: Task<Void, Never> = {
    Task {
      await self.initializeBuildings()
    }
  }()

  private init() {}

  static func getInstance() async -> ElectricityHelper {
    await shared.initializationTask.value
    return shared
  }

  private func initializeBuildings() async {
    do {
      for campus in Campus.allCases {
        let buildings = try await campusCardHelper.getBuildings(for: campus)

        self.buildings[campus] = Dictionary(uniqueKeysWithValues: buildings.map { ($0.name, $0) })
      }
    } catch {
      fatalError("Failed to initialize buildings: \(error)")
    }
  }

  func validLocation(campusName: String, buildingName: String) throws {
    guard let campus = Campus(rawValue: campusName) else {
      throw ElectricityHelperError.invalidCampus
    }
    guard buildings[campus]?[buildingName] != nil else {
      throw ElectricityHelperError.buildingNotFound
    }
  }

  func getElectricity(campusName: String, buildingName: String, room: String) async throws -> Double {
    guard let campus = Campus(rawValue: campusName) else {
      throw ElectricityHelperError.invalidCampus
    }
    guard let building = buildings[campus]?[buildingName] else {
      throw ElectricityHelperError.buildingNotFound
    }

    return try await campusCardHelper.getElectricity(building: building, room: room)
  }
}
