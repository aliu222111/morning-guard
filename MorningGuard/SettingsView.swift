import SwiftUI

// MARK: - Support links

private enum SupportLinks {
    static let appStoreID = "6793297906"
    static let feedbackAddress = "hello@morningguard.com"

    /// Deep link straight to the "Write a Review" sheet on the App Store.
    static var writeReview: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    /// Pre-filled feedback email with the app version, so reports are easy to triage.
    static var feedbackMail: URL? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = feedbackAddress
        comps.queryItems = [
            URLQueryItem(name: "subject", value: "Morning Guard feedback (v\(version))")
        ]
        return comps.url
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("mg.appearance") private var appearance = "dark"
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                MorningGradient().ignoresSafeArea()

                List {
                    // Appearance section
                    Section {
                        Picker(selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        } label: {
                            HStack {
                                SettingsIcon(name: "circle.lefthalf.filled", color: Color("Sunrise"))
                                Text("Theme")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appPrimaryText)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color("Sunrise"))
                    } header: {
                        Text("Appearance")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                            .tracking(1.2)
                            .textCase(.uppercase)
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))

                    // Privacy section
                    Section {
                        NavigationLink {
                            PrivacyView()
                        } label: {
                            HStack {
                                SettingsIcon(name: "lock.shield.fill", color: Color("Sunrise"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Privacy")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appPrimaryText)
                                    Text("Your data stays on your device")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                    } header: {
                        Text("Privacy")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                            .tracking(1.2)
                            .textCase(.uppercase)
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))

                    // Support section
                    Section {
                        Button {
                            if let url = SupportLinks.writeReview { openURL(url) }
                        } label: {
                            HStack {
                                SettingsIcon(name: "star.fill", color: Color("Sunrise"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Rate Morning Guard")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appPrimaryText)
                                    Text("Leave a review on the App Store")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }

                        Button {
                            if let url = SupportLinks.feedbackMail { openURL(url) }
                        } label: {
                            HStack {
                                SettingsIcon(name: "envelope.fill", color: Color("Sunrise"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Send feedback")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appPrimaryText)
                                    Text("Email me ideas, bugs, or anything else")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                    } header: {
                        Text("Support")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                            .tracking(1.2)
                            .textCase(.uppercase)
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))

                    // About section
                    Section {
                        HStack {
                            SettingsIcon(name: "info.circle.fill", color: Color("Sunrise"))
                            Text("Version 1.0")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appPrimaryText)
                            Spacer()
                            Text("Morning Guard")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .padding(.vertical, 2)

                        NavigationLink {
                            LicensesView()
                        } label: {
                            HStack {
                                SettingsIcon(name: "doc.text.fill", color: Color("Sunrise"))
                                Text("Acknowledgements")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appPrimaryText)
                            }
                        }

                        Button {
                            appState.hasCompletedOnboarding = false
                        } label: {
                            HStack {
                                SettingsIcon(name: "arrow.counterclockwise", color: .orange)
                                Text("Replay onboarding")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appPrimaryText)
                            }
                        }
                    } header: {
                        Text("About")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                            .tracking(1.2)
                            .textCase(.uppercase)
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.clear, for: .navigationBar)
        }
    }
}

// MARK: - Privacy

struct PrivacyView: View {
    private struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let permission: String
        let feature: String
    }

    private let items: [Item] = [
        Item(icon: "hourglass", permission: "Screen Time", feature: "Blocks the apps you choose during your morning window. Handled entirely by Apple's on-device Screen Time."),
        Item(icon: "bell.badge.fill", permission: "Notifications", feature: "Sends your halfway and completion reminders."),
        Item(icon: "camera.fill", permission: "Camera", feature: "Measures ambient light for the morning light step. No photo or video is captured or saved."),
        Item(icon: "waveform", permission: "Speech Recognition", feature: "Turns your dictation into text, on-device."),
        Item(icon: "gyroscope", permission: "Motion", feature: "Detects which way the phone faces so the right camera measures light."),
        Item(icon: "location.fill", permission: "Location", feature: "Used only to look up your local weather.")
    ]

    var body: some View {
        ZStack {
            MorningGradient().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Headline
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("Sunrise"))
                        Text("Everything stays on your device")
                            .font(.mg("Raleway-SemiBold", 22))
                            .foregroundStyle(Color.appPrimaryText)
                        Text("Morning Guard has no account, no servers, and no analytics. Your app selections and your morning progress are stored only on this iPhone and are never uploaded or shared.")
                            .font(.mg("Lora-Regular", 15))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(card)

                    // Permission → feature map
                    VStack(alignment: .leading, spacing: 0) {
                        Text("What each permission is for")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                            .tracking(1.2)
                            .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                                if i > 0 { Divider().opacity(0.35) }
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: item.icon)
                                        .foregroundStyle(Color("Sunrise"))
                                        .frame(width: 26)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.permission)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appPrimaryText)
                                        Text(item.feature)
                                            .font(.caption)
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(card)
                    }

                    // The one exception: weather
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "wifi")
                            .foregroundStyle(Color("Sunrise"))
                        Text("The only time Morning Guard uses the internet is to fetch your local weather. Your approximate location is sent to the weather provider for that lookup. Nothing else leaves your phone.")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .padding(16)
                    .background(card)

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.appCardFill)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .compositingGroup()
    }
}

// MARK: - Licenses / Acknowledgements

struct LicensesView: View {
    private struct Lib: Identifiable {
        let id = UUID()
        let name: String
        let license: String
        let detail: String
        var url: URL? = nil
    }

    private let libs: [Lib] = [
        Lib(name: "Raleway", license: "SIL Open Font License 1.1", detail: "Headings typeface."),
        Lib(name: "Lora", license: "SIL Open Font License 1.1", detail: "Reading typeface."),
        Lib(name: "Apple Weather", license: "Attribution", detail: "Weather data provided by  Weather.",
            url: URL(string: "https://weatherkit.apple.com/legal-attribution.html"))
    ]

    var body: some View {
        ZStack {
            MorningGradient().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Morning Guard is built with these open-source components. Thank you to their authors.")
                        .font(.mg("Lora-Regular", 15))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(libs.enumerated()), id: \.element.id) { i, lib in
                            if i > 0 { Divider().opacity(0.35) }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(lib.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appPrimaryText)
                                    Spacer()
                                    Text(lib.license)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Color("Sunrise"))
                                }
                                Text(lib.detail)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                if let url = lib.url {
                                    Link("Legal attribution", destination: url)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color("Sunrise"))
                                }
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.appCardFill)
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                            .compositingGroup()
                    )

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings Icon
struct SettingsIcon: View {
    let name: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: name)
                .foregroundStyle(color)
                .font(.system(size: 13))
        }
    }
}
