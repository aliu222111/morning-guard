#if os(iOS)
import ShieldConfiguration
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        return morningShieldConfiguration(appName: application.localizedDisplayName ?? "This app")
    }

    override func configuration(
        shielding application: Application,
        in webDomain: WebDomain
    ) -> ShieldConfiguration {
        return morningShieldConfiguration(appName: application.localizedDisplayName ?? "This app")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return morningShieldConfiguration(appName: webDomain.domain ?? "This site")
    }

    private func morningShieldConfiguration(appName: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: UIColor(red: 0.99, green: 0.96, blue: 0.93, alpha: 0.97),
            icon: UIImage(systemName: "sun.horizon.fill")?
                .withTintColor(.systemOrange, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(
                text: "Enjoy your morning first",
                color: UIColor(red: 0.47, green: 0.28, blue: 0.12, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(appName) is blocked during your morning window. Come back when you're ready.",
                color: UIColor(red: 0.69, green: 0.47, blue: 0.25, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go back",
                color: UIColor(red: 0.47, green: 0.28, blue: 0.12, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.8)
        )
    }
}
#endif
