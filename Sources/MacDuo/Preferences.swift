import Combine
import Foundation

/// User settings, backed by `UserDefaults`.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let isEnabled = "isEnabled"
        static let isTimeoutEnabled = "isTimeoutEnabled"
        static let thresholdAngle = "thresholdAngle"
        static let blurSpan = "blurSpan"
        static let maxBlurRadius = "maxBlurRadius"
        static let maxDim = "maxDim"
        static let viewingDistance = "viewingDistance"
        static let recession = "recession"
        static let blurEvenness = "blurEvenness"
        static let dimReach = "dimReach"
        static let showsAngleInMenuBar = "showsAngleInMenuBar"
        static let isLivePicture = "isLivePicture"
        static let activationSoundPath = "activationSoundPath"
        static let openingSoundPath = "openingSoundPath"

        static let all = [
            isEnabled, isTimeoutEnabled, thresholdAngle, blurSpan, maxBlurRadius,
            maxDim, viewingDistance, recession, blurEvenness, dimReach,
            showsAngleInMenuBar, isLivePicture, activationSoundPath, openingSoundPath,
        ]
    }

    private static let factory: [String: Any] = [
        Key.isEnabled: true,
        Key.isTimeoutEnabled: false,
        Key.thresholdAngle: 90.0,
        Key.blurSpan: 60.0,
        Key.maxBlurRadius: 135.0,
        Key.maxDim: 1.0,
        Key.viewingDistance: 6.0,
        Key.recession: 1.0,
        Key.blurEvenness: 0.0,
        Key.dimReach: 0.5,
        Key.showsAngleInMenuBar: false,
        Key.isLivePicture: true,
        Key.activationSoundPath: "",
        Key.openingSoundPath: "",
    ]

    /// Master switch for the depth effect.
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    /// Ends the effect early if the angle holds still while below the
    /// threshold, instead of waiting for the lid to open back past it.
    @Published var isTimeoutEnabled: Bool {
        didSet { defaults.set(isTimeoutEnabled, forKey: Key.isTimeoutEnabled) }
    }

    /// Closing past this angle starts the depth effect. Degrees.
    @Published var thresholdAngle: Double {
        didSet { defaults.set(thresholdAngle, forKey: Key.thresholdAngle) }
    }

    /// How many degrees below the threshold the blur takes to reach maximum.
    @Published var blurSpan: Double {
        didSet { defaults.set(blurSpan, forKey: Key.blurSpan) }
    }

    /// Gaussian blur radius at full effect, in points.
    @Published var maxBlurRadius: Double {
        didSet { defaults.set(maxBlurRadius, forKey: Key.maxBlurRadius) }
    }

    /// Black overlay opacity where the blur is at full strength, 0...1.
    @Published var maxDim: Double {
        didSet { defaults.set(maxDim, forKey: Key.maxDim) }
    }

    /// Distance from the eye to the middle of the screen, as a multiple of
    /// the screen height.
    @Published var viewingDistance: Double {
        didSet { defaults.set(viewingDistance, forKey: Key.viewingDistance) }
    }

    /// Degrees the picture turns away from the glass for each degree the lid
    /// closes. One holds the picture still in the room.
    @Published var recession: Double {
        didSet { defaults.set(recession, forKey: Key.recession) }
    }

    /// Blur at the hinge edge as a fraction of the blur at the far edge. One
    /// blurs the whole picture by the same amount.
    @Published var blurEvenness: Double {
        didSet { defaults.set(blurEvenness, forKey: Key.blurEvenness) }
    }

    /// Height at which the dimming reaches full strength, as a fraction of
    /// the screen height.
    @Published var dimReach: Double {
        didSet { defaults.set(dimReach, forKey: Key.dimReach) }
    }

    /// Draw the live angle next to the menu bar icon.
    @Published var showsAngleInMenuBar: Bool {
        didSet { defaults.set(showsAngleInMenuBar, forKey: Key.showsAngleInMenuBar) }
    }

    /// Keep the picture under the effect updating, instead of holding the one
    /// frame that was on screen at the trigger angle.
    @Published var isLivePicture: Bool {
        didSet { defaults.set(isLivePicture, forKey: Key.isLivePicture) }
    }

    /// Empty uses the built-in system sound; otherwise this is a user-selected audio file.
    @Published var activationSoundPath: String {
        didSet { defaults.set(activationSoundPath, forKey: Key.activationSoundPath) }
    }

    /// Empty uses the built-in opening sound; otherwise this is the app-owned copy.
    @Published var openingSoundPath: String {
        didSet { defaults.set(openingSoundPath, forKey: Key.openingSoundPath) }
    }

    private static var soundsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mac Duo", isDirectory: true)
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    /// Copies a selected sound into app-owned storage so it remains available
    /// if the original is moved or deleted.
    func importActivationSound(from source: URL) throws {
        let previous = activationSoundPath
        let destination = try importSound(from: source, subdirectory: "Closing")
        activationSoundPath = destination.path
        removeImportedSound(atPath: previous, except: destination)
    }

    func importOpeningSound(from source: URL) throws {
        let previous = openingSoundPath
        let destination = try importSound(from: source, subdirectory: "Opening")
        openingSoundPath = destination.path
        removeImportedSound(atPath: previous, except: destination)
    }

    private func importSound(from source: URL, subdirectory: String) throws -> URL {
        let accessing = source.startAccessingSecurityScopedResource()
        defer {
            if accessing { source.stopAccessingSecurityScopedResource() }
        }

        let fileManager = FileManager.default
        let directory = Self.soundsDirectory.appendingPathComponent(subdirectory, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let staged = directory.appendingPathComponent(".import-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: staged) }
        try fileManager.copyItem(at: source, to: staged)

        let destination = directory.appendingPathComponent(source.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: staged, to: destination)

        for file in try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) where file != destination {
            try? fileManager.removeItem(at: file)
        }
        return destination
    }

    func useSystemActivationSound() {
        let previous = activationSoundPath
        activationSoundPath = ""
        removeImportedSound(atPath: previous)
    }

    func useSystemOpeningSound() {
        let previous = openingSoundPath
        openingSoundPath = ""
        removeImportedSound(atPath: previous)
    }

    private func removeImportedSound(atPath path: String, except retained: URL? = nil) {
        guard !path.isEmpty else { return }
        let imported = URL(fileURLWithPath: path).standardizedFileURL
        let basePath = Self.soundsDirectory.standardizedFileURL.path + "/"
        guard imported.path.hasPrefix(basePath), imported != retained else { return }
        try? FileManager.default.removeItem(at: imported)
    }

    /// Eye distance in screen heights, at the two ends of the perspective
    /// slider. The panel offers the strength, which runs the other way.
    static let farthestEye: Double = 6
    static let nearestEye: Double = 1
    static let eyeRange: Double = farthestEye - nearestEye

    /// Highest angle above the threshold at which the pre-warm may run.
    let prewarmCeiling: Double = 70

    /// Closing speed in degrees per second that starts the pre-warm.
    let closingSpeed: Double = 8

    /// How long the pre-warm runs after the lid stops moving.
    let prewarmLinger: TimeInterval = 2

    /// Seconds between pre-warm screenshots.
    let prewarmInterval: TimeInterval = 0.25

    /// Degrees above the threshold before the overlay is released.
    let hysteresis: Double = 4

    /// Settings from earlier versions, removed at launch.
    private static let retired = [
        "blurFrontWidth", "maxTilt", "tiltDegrees", "tiltRatio", "dimEvenness",
    ]

    private let defaults = UserDefaults.standard

    // No inline values on purpose. Swift skips property observers for the
    // assignment that initialises a property.
    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: Self.factory)
        for key in Self.retired { defaults.removeObject(forKey: key) }
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        isTimeoutEnabled = defaults.bool(forKey: Key.isTimeoutEnabled)
        thresholdAngle = defaults.double(forKey: Key.thresholdAngle)
        blurSpan = defaults.double(forKey: Key.blurSpan)
        maxBlurRadius = defaults.double(forKey: Key.maxBlurRadius)
        maxDim = defaults.double(forKey: Key.maxDim)
        viewingDistance = defaults.double(forKey: Key.viewingDistance)
        recession = defaults.double(forKey: Key.recession)
        blurEvenness = defaults.double(forKey: Key.blurEvenness)
        dimReach = defaults.double(forKey: Key.dimReach)
        showsAngleInMenuBar = defaults.bool(forKey: Key.showsAngleInMenuBar)
        isLivePicture = defaults.bool(forKey: Key.isLivePicture)
        activationSoundPath = defaults.string(forKey: Key.activationSoundPath) ?? ""
        openingSoundPath = defaults.string(forKey: Key.openingSoundPath) ?? ""

        if !activationSoundPath.isEmpty {
            let current = URL(fileURLWithPath: activationSoundPath).standardizedFileURL
            let closingDirectory = Self.soundsDirectory
                .appendingPathComponent("Closing", isDirectory: true)
                .standardizedFileURL
            if current.deletingLastPathComponent() != closingDirectory,
               FileManager.default.fileExists(atPath: current.path) {
                try? importActivationSound(from: current)
            }
        }
    }

    func resetToDefaults() {
        useSystemActivationSound()
        useSystemOpeningSound()
        for key in Key.all {
            defaults.removeObject(forKey: key)
        }
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        isTimeoutEnabled = defaults.bool(forKey: Key.isTimeoutEnabled)
        thresholdAngle = defaults.double(forKey: Key.thresholdAngle)
        blurSpan = defaults.double(forKey: Key.blurSpan)
        maxBlurRadius = defaults.double(forKey: Key.maxBlurRadius)
        maxDim = defaults.double(forKey: Key.maxDim)
        viewingDistance = defaults.double(forKey: Key.viewingDistance)
        recession = defaults.double(forKey: Key.recession)
        blurEvenness = defaults.double(forKey: Key.blurEvenness)
        dimReach = defaults.double(forKey: Key.dimReach)
        showsAngleInMenuBar = defaults.bool(forKey: Key.showsAngleInMenuBar)
        isLivePicture = defaults.bool(forKey: Key.isLivePicture)
        activationSoundPath = defaults.string(forKey: Key.activationSoundPath) ?? ""
        openingSoundPath = defaults.string(forKey: Key.openingSoundPath) ?? ""
    }
}
