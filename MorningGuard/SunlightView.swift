import SwiftUI
import AVFoundation
import Combine
import CoreMotion
import UIKit

// MARK: - LightQuality

enum LightQuality: Equatable {
    case indoors, overcast, bright

    init(lux: Double) {
        if lux >= 10_000 { self = .bright }
        else if lux >= 1_000 { self = .overcast }
        else { self = .indoors }
    }

    var label: String {
        switch self {
        case .indoors:  return "Indoors"
        case .overcast: return "Outdoor"
        case .bright:   return "Bright sun"
        }
    }

    /// Session target in seconds. 0 means no timer should run.
    var targetSeconds: Int {
        switch self {
        case .indoors:  return 0
        case .overcast: return 1_200   // 20 min
        case .bright:   return 420     // 7 min
        }
    }

    var targetLabel: String {
        switch self {
        case .indoors:  return "Go outside"
        case .overcast: return "20 min"
        case .bright:   return "7 min"
        }
    }

    var tip: String {
        switch self {
        case .indoors:
            return "Indoor light is 10-100x too dim to trigger the morning cortisol pulse. Step outside or open a door."
        case .overcast:
            return "Overcast outdoor light still delivers 1,000-10,000 lux, enough for ipRGC cells to fire. Aim for 20 minutes."
        case .bright:
            return "Direct sun delivers 10,000+ lux. Just 7 minutes is enough to set your circadian clock for the day."
        }
    }

    var accentColorName: String {
        switch self {
        case .indoors:  return "WarmTan"
        case .overcast: return "PillGreen"
        case .bright:   return "Sunrise"
        }
    }
}

// MARK: - SunlightService

final class SunlightService: NSObject, ObservableObject {
    // NOT @MainActor — AVFoundation delegate callbacks arrive on a background queue.

    @Published var luxLevel: Double = 0
    @Published var permissionDenied: Bool = false
    @Published var activeCameraLabel: String = ""

    private var session: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private let sampleQueue = DispatchQueue(label: "com.morningguard.sunlight.sample", qos: .userInitiated)
    private let motion = CMMotionManager()

    private var luxSamples: [(time: Date, lux: Double)] = []
    private let averagingWindow: TimeInterval = 5.0
    private let publishInterval: TimeInterval = 1.0   // refresh the shown number once/sec
    private var lastPublishTime: Date = .distantPast

    func start() {
        startMotion()
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if granted {
                Task { @MainActor [weak self] in self?.setupSession() }
            } else {
                Task { @MainActor in self.permissionDenied = true }
            }
        }
    }

    func stop() {
        session?.stopRunning()
        session = nil
        activeDevice = nil
        motion.stopDeviceMotionUpdates()
        // Clear the buffer on the queue that mutates it, to avoid racing the
        // capture delegate (which appends samples on sampleQueue).
        sampleQueue.async { [weak self] in
            self?.luxSamples.removeAll()
            self?.lastPublishTime = .distantPast
        }
        Task { @MainActor [weak self] in self?.luxLevel = 0 }
    }

    // MARK: Private

    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.2
        motion.startDeviceMotionUpdates(to: .main) { _, _ in }
    }

    /// Picks the camera that is facing UP (toward the sky), so a phone resting
    /// on a table still measures light. Face-up on a table → front camera sees
    /// the sky; face-down → back camera sees the sky; handheld → back camera.
    private func preferredCameraPosition() -> AVCaptureDevice.Position {
        guard let z = motion.deviceMotion?.gravity.z else { return .back }
        if z < -0.7 { return .front }   // screen up → front camera faces sky
        if z > 0.7 { return .back }     // screen down → back camera faces sky
        return .back                    // upright / handheld
    }

    private func cameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let d = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return d
        }
        // Fall back to whatever video camera exists.
        return AVCaptureDevice.default(for: .video)
    }

    private func setupSession() {
        let newSession = AVCaptureSession()
        newSession.sessionPreset = .low

        let position = preferredCameraPosition()
        guard let device = cameraDevice(for: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if newSession.canAddInput(input) { newSession.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sampleQueue)

        if newSession.canAddOutput(output) { newSession.addOutput(output) }

        session = newSession
        activeDevice = device

        let label = device.position == .front ? "Front camera" : "Back camera"
        Task { @MainActor [weak self] in self?.activeCameraLabel = label }

        Task.detached(priority: .userInitiated) { [newSession] in
            newSession.startRunning()
        }
    }

    private func calculateLux(device: AVCaptureDevice) -> Double {
        let aperture = Double(device.lensAperture)
        let duration = CMTimeGetSeconds(device.exposureDuration)
        let iso = device.iso

        guard duration > 0, iso > 0, aperture > 0 else { return 0 }

        let ev100 = log2((aperture * aperture) / duration) - log2(Double(iso) / 100.0)
        return 2.5 * pow(2.0, ev100)
    }
}

extension SunlightService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()

        guard let device = activeDevice ?? AVCaptureDevice.default(for: .video) else { return }

        let lux = calculateLux(device: device)

        // Time-stamped buffer: keep only the trailing averaging window and
        // publish its mean.
        luxSamples.append((time: now, lux: lux))
        luxSamples.removeAll { now.timeIntervalSince($0.time) > averagingWindow }

        // Refresh the displayed number only once per second so it reads steadily
        // instead of twitching on every frame.
        guard now.timeIntervalSince(lastPublishTime) >= publishInterval else { return }
        lastPublishTime = now

        let mean = luxSamples.reduce(0) { $0 + $1.lux } / Double(luxSamples.count)
        let rounded = Self.niceRound(mean)

        Task { @MainActor [weak self] in
            self?.luxLevel = rounded
        }
    }

    /// Round to a "nice" value so small fluctuations in the mean don't change
    /// the shown number.
    private static func niceRound(_ v: Double) -> Double {
        switch v {
        case ..<100:    return (v / 5).rounded() * 5
        case ..<1_000:  return (v / 10).rounded() * 10
        case ..<10_000: return (v / 50).rounded() * 50
        default:        return (v / 100).rounded() * 100
        }
    }
}

// MARK: - SunlightViewModel

@MainActor
final class SunlightViewModel: ObservableObject {
    @Published var elapsedSeconds: Int = 0
    @Published var isTracking: Bool = false
    @Published var luxLevel: Double = 0
    @Published var permissionDenied: Bool = false

    /// The goal is pinned the first time the light qualifies this session, so a
    /// passing cloud that drops lux from "bright" to "overcast" can't retroactively
    /// raise the target and undo a nearly-finished session. 0 = not yet established.
    @Published var sessionTarget: Int = 0

    private let service = SunlightService()
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?

    init() {
        service.$luxLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$luxLevel)

        service.$permissionDenied
            .receive(on: DispatchQueue.main)
            .assign(to: &$permissionDenied)
    }

    var quality: LightQuality { LightQuality(lux: luxLevel) }

    /// The goal in effect: the pinned session target once counting has begun,
    /// otherwise the live estimate for the current light.
    private var effectiveTarget: Int {
        sessionTarget > 0 ? sessionTarget : quality.targetSeconds
    }

    var progress: Double {
        let target = effectiveTarget
        guard target > 0 else { return 0 }
        return min(1.0, Double(elapsedSeconds) / Double(target))
    }

    var isGoalMet: Bool {
        effectiveTarget > 0 && elapsedSeconds >= effectiveTarget
    }

    var formattedElapsed: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func startTracking() {
        // Start each measurement from a clean slate so a prior session's elapsed
        // time and pinned target can't leak into this one.
        reset()
        service.start()
        isTracking = true

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Only count time when light level qualifies
                if self.luxLevel >= 1_000 {
                    // Pin the target to the first qualifying reading of the session.
                    if self.sessionTarget == 0 {
                        self.sessionTarget = LightQuality(lux: self.luxLevel).targetSeconds
                    }
                    self.elapsedSeconds += 1
                }
            }
    }

    func stopTracking() {
        service.stop()
        timerCancellable?.cancel()
        timerCancellable = nil
        isTracking = false
    }

    func reset() {
        elapsedSeconds = 0
        sessionTarget = 0
    }
}
