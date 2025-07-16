import CSUSTKit

enum ElectricityHelperError: Error {
    case invalidCampus
    case buildingNotFound
}

actor ElectricityHelper {
    private let campusCardHelper = CampusCardHelper()
    private var buildings: [Campus: [String: Building]] = [:]

    static var shared: ElectricityHelper = ElectricityHelper()

    private init() {
        Task {
            await initializeBuildings()
        }
    }

    private func initializeBuildings() async {
        do {
            for campus in Campus.allCases {
                let buildings = try await campusCardHelper.getBuildings(for: campus)

                self.buildings[campus] = Dictionary(
                    uniqueKeysWithValues: buildings.map { ($0.name, $0) })
            }
        } catch {
            fatalError("Failed to initialize buildings: \(error)")
        }
    }

    func validLocation(campusName: String, buildingName: String) -> Bool {
        guard let campus = Campus(rawValue: campusName) else { return false }
        guard buildings[campus]?[buildingName] != nil else { return false }
        return true
    }

    func getElectricity(campusName: String, buildingName: String, room: String) async throws
        -> Double
    {
        guard let campus = Campus(rawValue: campusName) else {
            throw ElectricityHelperError.invalidCampus
        }
        guard let building = buildings[campus]?[buildingName] else {
            throw ElectricityHelperError.buildingNotFound
        }

        return try await campusCardHelper.getElectricity(building: building, room: room)
    }
}
