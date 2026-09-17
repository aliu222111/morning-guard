import Foundation
import CoreLocation
import Combine
import WeatherKit

/// Fetches the local current weather using the device location and Apple's
/// WeatherKit. Fails silently (available stays false) if location or the
/// service is unavailable, so the Home header just omits the weather.
final class WeatherService: NSObject, ObservableObject {

    @Published var temperatureText: String = ""
    @Published var highText: String = ""
    @Published var lowText: String = ""
    @Published var conditionSymbol: String = "cloud.fill"
    @Published var conditionText: String = ""
    @Published var cityName: String = ""
    @Published var available: Bool = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Ask for permission if needed, then request a one-shot location.
    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    @MainActor
    private func loadWeather(for location: CLLocation) async {
        let unit: UnitTemperature = usesFahrenheit ? .fahrenheit : .celsius
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let today = weather.dailyForecast.first

            let temp = Int(current.temperature.converted(to: unit).value.rounded())
            temperatureText = "\(temp)°"
            if let hi = today?.highTemperature.converted(to: unit).value {
                highText = "\(Int(hi.rounded()))°"
            }
            if let lo = today?.lowTemperature.converted(to: unit).value {
                lowText = "\(Int(lo.rounded()))°"
            }
            conditionSymbol = current.symbolName
            conditionText = current.condition.description
            available = true
        } catch {
            // Leave `available` false; the header simply won't show weather.
            #if DEBUG
            NSLog("[MorningGuard] WeatherKit fetch failed: %@", error.localizedDescription)
            #endif
        }
    }

    private var usesFahrenheit: Bool {
        Locale.current.measurementSystem == .us
    }

    private func reverseGeocode(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let city = placemarks?.first?.locality else { return }
            Task { @MainActor [weak self] in self?.cityName = city }
        }
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor [weak self] in
            await self?.loadWeather(for: loc)
            self?.reverseGeocode(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore; weather just won't appear.
    }
}
