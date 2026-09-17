import SwiftUI
import UIKit

// MARK: - Water

/// The simpler of the two: a tick box with a reason attached.
struct WaterCard: View {
    @ObservedObject var tasks: MorningTasks

    private var done: Bool { tasks.isDone(.water) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: MorningTasks.Task.water.symbol)
                    .font(.subheadline)
                    .foregroundStyle(Color("Sunrise"))
                Text(MorningTasks.Task.water.title)
                    .font(.mg("Raleway-SemiBold", 20))
                    .foregroundStyle(Color.appPrimaryText)
                Spacer(minLength: 0)
                Doodle("doodle-step-water", maxHeight: 44)
            }

            Text(MorningTasks.Task.water.detail)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                tasks.toggle(.water)
            } label: {
                Label(done ? "Done" : "I drank water",
                      systemImage: done ? "checkmark.circle.fill" : "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(done ? Color("PillGreen") : Color("Sunrise"))
                    .foregroundStyle(done ? Color("PillGreenText") : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(morningCard)
    }
}

// MARK: - Morning light

/// Wraps the camera lux meter. Marks itself done once the exposure target for
/// the measured light quality is met, since that is the actual goal rather than
/// the tapping.
struct LightCard: View {
    @ObservedObject var tasks: MorningTasks
    @StateObject private var sunlight = SunlightViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: MorningTasks.Task.light.symbol)
                    .foregroundStyle(Color("Sunrise"))
                if sunlight.luxLevel >= 10 {
                    Text(Int(sunlight.luxLevel).formatted())
                        .font(.mg("Raleway-Medium", 34))
                        .foregroundStyle(Color.appPrimaryText)
                        .monospacedDigit()
                    Text("lux")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                } else {
                    Text(sunlight.isTracking ? "Measuring light…" : "Get morning light")
                        .font(.mg("Raleway-SemiBold", 20))
                        .foregroundStyle(sunlight.isTracking ? Color.secondaryText : Color.appPrimaryText)
                }
                Spacer(minLength: 0)
                if sunlight.luxLevel >= 10 || sunlight.isTracking {
                    Text(sunlight.quality.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(sunlight.quality.accentColorName).opacity(0.22))
                        .foregroundStyle(Color(sunlight.quality.accentColorName))
                        .clipShape(Capsule())
                } else if tasks.isDone(.light) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("Sunrise"))
                } else {
                    Doodle("doodle-step-light", maxHeight: 44)
                }
            }

            if sunlight.isTracking {
                HStack {
                    Text(sunlight.formattedElapsed)
                        .font(.mg("Raleway-Medium", 20))
                        .foregroundStyle(Color.appPrimaryText)
                        .monospacedDigit()
                    Text("/ \(sunlight.quality.targetLabel)")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                    Spacer()
                    if sunlight.isGoalMet {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color("Sunrise"))
                    }
                }
                ProgressView(value: sunlight.progress).tint(Color("Sunrise"))
            }

            Text(sunlight.isTracking ? sunlight.quality.tip : MorningTasks.Task.light.detail)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if sunlight.isTracking { sunlight.stopTracking() } else { sunlight.startTracking() }
            } label: {
                Text(sunlight.isTracking ? "Stop" : "Measure light")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(sunlight.isTracking ? Color.red.opacity(0.85) : Color("Sunrise"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if sunlight.isTracking {
                Text("Lay the phone flat or point a camera at the sky. We use whichever camera faces up.")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(morningCard)
        .onChange(of: sunlight.isGoalMet) { _, met in
            if met { tasks.setDone(.light, true) }
        }
        .alert("Camera Access Needed", isPresented: $sunlight.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Morning Guard measures ambient light with the camera. No images are captured or stored.")
        }
    }
}
