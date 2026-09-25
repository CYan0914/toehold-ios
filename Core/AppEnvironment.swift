import Foundation

/// Launch-argument switches, used only by the screenshot job.
///
/// The alternative is a UI test that drives taps to reach each screen, which is
/// slower, breaks whenever a control moves, and photographs whatever the test
/// happened to hit rather than a known state. Launching straight onto a screen
/// with fixed data means the pictures are of the app, not of an automation
/// script's timing.
///
/// `-ToeholdDemo <screen>` where screen is one of `DemoScreen`. Bare
/// `-ToeholdDemo` (or with no recognisable screen name) means "demo data, open
/// on home". Absent means normal launch, which is what everyone who is not CI
/// gets.
enum AppEnvironment {
    enum DemoScreen: String {
        case home
        case runner
        case done
        case allsteps
    }

    static var demoScreen: DemoScreen? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-ToeholdDemo") else { return nil }
        let next = args.indices.contains(index + 1) ? args[index + 1] : ""
        // A bare `-ToeholdDemo` is followed by nothing, or by the next flag.
        // Both mean "home" rather than "unknown screen".
        guard !next.hasPrefix("-") else { return .home }
        return DemoScreen(rawValue: next) ?? .home
    }

    static var isDemo: Bool { demoScreen != nil }
}
