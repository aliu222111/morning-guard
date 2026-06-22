import SwiftUI
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var guardVM: GuardViewModel

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:     return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MorningGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.custom("Georgia", size: 28))
                                .italic()
                                .foregroundStyle(Color("WarmBrown"))
                            Text(Date().formatted(date: .complete, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(Color("WarmTan"))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Status Card
                        GuardStatusCard()
                            .padding(.horizontal)

                        // Blocked Apps List
                        if !guardVM.selectedApps.applicationTokens.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel(text: "Blocked apps")
                                BlockedAppsList()
                            }
                        } else {
                            EmptyAppsPrompt()
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Morning Gradient Background
struct MorningGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color("DawnPink"), Color("MorningCream")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Guard Status Card
struct GuardStatusCard: View {
    @EnvironmentObject var guardVM: GuardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Morning Guard")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("WarmBrown"))
                    .tracking(1.2)
                    .textCase(.uppercase)
                Spacer()
                StatusPill(isActive: guardVM.isGuardActive)
            }

            if guardVM.isGuardActive {
                VStack(alignment: .leading, spacing: 4) {
                    Text(guardVM.timeRemainingFormatted)
                        .font(.custom("Georgia", size: 48))
                        .foregroundStyle(Color("WarmBrown"))
                    Text("remaining in your morning window")
                        .font(.caption)
                        .foregroundStyle(Color("WarmTan"))
                }

                ProgressView(value: guardVM.progressFraction)
                    .tint(Color("Sunrise"))
                    .scaleEffect(x: 1, y: 1.5)

            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Guard is resting")
                        .font(.custom("Georgia", size: 22))
                        .italic()
                        .foregroundStyle(Color("WarmBrown"))
                    Text("Will activate on your first unlock tomorrow morning.")
                        .font(.caption)
                        .foregroundStyle(Color("WarmTan"))
                }

                Button {
                    guardVM.startMorningGuard()
                } label: {
                    Label("Start now", systemImage: "sun.rise.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("Sunrise"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color("CardGold").opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color("WarmTan").opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Status Pill
struct StatusPill: View {
    let isActive: Bool
    var body: some View {
        Text(isActive ? "Active" : "Resting")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isActive ? Color("PillGreen") : Color.secondary.opacity(0.15))
            .foregroundStyle(isActive ? Color("PillGreenText") : .secondary)
            .clipShape(Capsule())
    }
}

// MARK: - Section Label
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color("WarmTan"))
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal)
    }
}

// MARK: - Brand Logo Views

struct InstagramLogo: View {
    var size: CGFloat = 40
    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width
            let gradient = Gradient(colors: [
                Color(red: 1.00, green: 0.84, blue: 0.00),
                Color(red: 1.00, green: 0.48, blue: 0.00),
                Color(red: 1.00, green: 0.00, blue: 0.41),
                Color(red: 0.83, green: 0.00, blue: 0.77),
                Color(red: 0.46, green: 0.22, blue: 0.98)
            ])
            let rect = CGRect(origin: .zero, size: sz)
            ctx.fill(
                Path(roundedRect: rect, cornerRadius: s * 0.25),
                with: .linearGradient(gradient,
                    startPoint: CGPoint(x: s * 0.2, y: s),
                    endPoint: CGPoint(x: s * 0.8, y: 0))
            )
            // Outer square ring
            let ring = CGRect(x: s*0.275, y: s*0.275, width: s*0.45, height: s*0.45)
            var ringPath = Path(roundedRect: ring, cornerRadius: s*0.13)
            ctx.stroke(ringPath, with: .color(.white), style: StrokeStyle(lineWidth: s*0.05))
            // Inner circle
            let circleRect = CGRect(x: s*0.375, y: s*0.375, width: s*0.25, height: s*0.25)
            ctx.stroke(Path(ellipseIn: circleRect), with: .color(.white), style: StrokeStyle(lineWidth: s*0.05))
            // Dot
            let dot = CGRect(x: s*0.615, y: s*0.27, width: s*0.075, height: s*0.075)
            ctx.fill(Path(ellipseIn: dot), with: .color(.white))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
    }
}

struct TikTokLogo: View {
    var size: CGFloat = 40
    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width
            ctx.fill(
                Path(roundedRect: CGRect(origin: .zero, size: sz),
                     cornerRadius: s * 0.25),
                with: .color(.black)
            )
            // Musical note / TikTok shape
            var p = Path()
            p.move(to: CGPoint(x: s*0.56, y: s*0.20))
            p.addLine(to: CGPoint(x: s*0.56, y: s*0.575))
            let noteCircle = CGRect(x: s*0.34, y: s*0.55, width: s*0.22, height: s*0.22)
            p.addEllipse(in: noteCircle)
            ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: s*0.075, lineCap: .round))
            // Right side curve (the flag)
            var flag = Path()
            flag.move(to: CGPoint(x: s*0.56, y: s*0.20))
            flag.addCurve(
                to: CGPoint(x: s*0.76, y: s*0.305),
                control1: CGPoint(x: s*0.66, y: s*0.20),
                control2: CGPoint(x: s*0.76, y: s*0.24)
            )
            ctx.stroke(flag, with: .color(.white), style: StrokeStyle(lineWidth: s*0.075, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct XTwitterLogo: View {
    var size: CGFloat = 40
    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width
            ctx.fill(
                Path(roundedRect: CGRect(origin: .zero, size: sz),
                     cornerRadius: s * 0.25),
                with: .color(.black)
            )
            // X shape
            var x = Path()
            x.move(to: CGPoint(x: s*0.22, y: s*0.23))
            x.addLine(to: CGPoint(x: s*0.78, y: s*0.77))
            x.move(to: CGPoint(x: s*0.78, y: s*0.23))
            x.addLine(to: CGPoint(x: s*0.22, y: s*0.77))
            ctx.stroke(x, with: .color(.white), style: StrokeStyle(lineWidth: s*0.09, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct FacebookLogo: View {
    var size: CGFloat = 40
    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width
            ctx.fill(
                Path(roundedRect: CGRect(origin: .zero, size: sz),
                     cornerRadius: s * 0.25),
                with: .color(Color(red: 0.094, green: 0.467, blue: 0.949))
            )
            // f shape
            var f = Path()
            // Vertical stem
            f.move(to: CGPoint(x: s*0.50, y: s*0.38))
            f.addLine(to: CGPoint(x: s*0.50, y: s*0.82))
            ctx.stroke(f, with: .color(.white), style: StrokeStyle(lineWidth: s*0.10, lineCap: .round))
            // Cross bar
            var bar = Path()
            bar.move(to: CGPoint(x: s*0.36, y: s*0.535))
            bar.addLine(to: CGPoint(x: s*0.62, y: s*0.535))
            ctx.stroke(bar, with: .color(.white), style: StrokeStyle(lineWidth: s*0.09, lineCap: .round))
            // Top curve of f
            var curve = Path()
            curve.move(to: CGPoint(x: s*0.50, y: s*0.38))
            curve.addCurve(
                to: CGPoint(x: s*0.66, y: s*0.255),
                control1: CGPoint(x: s*0.50, y: s*0.29),
                control2: CGPoint(x: s*0.66, y: s*0.255)
            )
            ctx.stroke(curve, with: .color(.white), style: StrokeStyle(lineWidth: s*0.09, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Blocked Apps List

struct BlockedAppsList: View {
    @EnvironmentObject var guardVM: GuardViewModel

    var body: some View {
        VStack(spacing: 8) {
            AppBlockRow(name: "Instagram", isLocked: guardVM.isGuardActive) {
                InstagramLogo(size: 40)
            }
            AppBlockRow(name: "TikTok", isLocked: guardVM.isGuardActive) {
                TikTokLogo(size: 40)
            }
            AppBlockRow(name: "X / Twitter", isLocked: guardVM.isGuardActive) {
                XTwitterLogo(size: 40)
            }
            AppBlockRow(name: "Facebook", isLocked: guardVM.isGuardActive) {
                FacebookLogo(size: 40)
            }
        }
        .padding(.horizontal)
    }
}

struct AppBlockRow<Logo: View>: View {
    let name: String
    let isLocked: Bool
    @ViewBuilder let logo: () -> Logo

    var body: some View {
        HStack(spacing: 12) {
            logo()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("WarmBrown"))
                Text(isLocked ? "Blocked during morning window" : "Will block tomorrow")
                    .font(.caption)
                    .foregroundStyle(Color("WarmTan"))
            }
            Spacer()
            Image(systemName: isLocked ? "lock.fill" : "lock.open")
                .foregroundStyle(isLocked ? Color("Sunrise") : Color.secondary.opacity(0.4))
                .font(.system(size: 14))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color("WarmTan").opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Empty State
struct EmptyAppsPrompt: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "shield.slash")
                .font(.largeTitle)
                .foregroundStyle(Color("WarmTan"))
            Text("No apps selected yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("WarmBrown"))
            Text("Go to Guard to choose which apps to block during your morning window.")
                .font(.caption)
                .foregroundStyle(Color("WarmTan"))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.5))
        )
    }
}
