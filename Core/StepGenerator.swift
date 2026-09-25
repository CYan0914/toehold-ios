import Foundation

/// Where a task's steps came from. Surfaced in the UI as a small label and
/// stored on `TaskItem.sourceRaw`, so the raw value is load-bearing: changing a
/// case name rewrites what existing rows mean.
enum StepSource: String, Codable, CaseIterable, Sendable {
    /// Generated on device by Apple's foundation model.
    case ai
    /// Picked from the built-in self-care chains.
    case template
    /// The person wrote the steps themselves.
    case manual
}

/// The self-care situations the template path knows about.
///
/// This list is the product's positioning made concrete: every case is
/// something a person has to do to stay well, not something they have to do to
/// be productive. The App Store copy promises "self care first", and the only
/// place that promise is kept or broken is this enum plus the chains in
/// `CareScenarios`.
enum CareScenario: String, Codable, CaseIterable, Sendable {
    case hygiene
    case shower
    case medication
    case wakingUp
    case eating
    case dishes
    case laundry
    case leavingHome

    /// Shown on the scenario picker. Phrased as the person's own complaint
    /// rather than as a category name -- "I can't get in the shower" is what
    /// they are thinking; "Hygiene" is what a product manager is thinking.
    var title: String {
        switch self {
        case .hygiene: "Brush my teeth"
        case .shower: "Take a shower"
        case .medication: "Take my meds"
        case .wakingUp: "Get out of bed"
        case .eating: "Make something to eat"
        case .dishes: "Do the dishes"
        case .laundry: "Start the laundry"
        case .leavingHome: "Leave the house"
        }
    }

    var symbolName: String {
        switch self {
        case .hygiene: "mouth"
        case .shower: "shower"
        case .medication: "pills"
        case .wakingUp: "sunrise"
        case .eating: "fork.knife"
        case .dishes: "sink"
        case .laundry: "washer"
        case .leavingHome: "door.left.hand.open"
        }
    }
}

/// A generated step, before it becomes a `StepItem`. A plain value type so the
/// generators can be tested without a ModelContainer anywhere in sight.
struct StepDraft: Equatable, Sendable {
    var text: String
}

/// What the UI calls to turn "I'm stuck on X" into a list of steps.
///
/// Two implementations exist and they are not equal in quality -- the AI one
/// handles anything the person types, the template one handles the eight
/// situations in `CareScenario` and falls back to a generic opener for
/// everything else. That asymmetry is deliberate and invisible on purpose: the
/// UI asks the factory for a generator and never learns which one it got. A
/// person on an older phone gets a working app, not a degraded one with an
/// explanation they did not ask for.
protocol StepGenerator: Sendable {
    /// Which implementation this is. Read by the caller to stamp the created
    /// task, so the history can say where its steps came from. Declared on the
    /// protocol rather than derived by the caller with a type check, because a
    /// type check needs `#available` to name the AI type and that turns one
    /// line of bookkeeping into a version-gated branch at every call site.
    var source: StepSource { get }

    func generateSteps(for title: String, category: CareScenario?) async throws -> [StepDraft]
}

enum StepGeneratorError: Error, LocalizedError {
    /// The model cannot run: no Apple Intelligence support, an unsupported
    /// region, or the feature switched off in Settings. The caller should fall
    /// back to `TemplateStepGenerator` rather than showing an error — the
    /// person did nothing to cause this and has nothing to fix.
    case modelUnavailable
    /// The model ran and returned nothing usable. A refusal is a successful
    /// call with an empty answer, so it arrives here rather than as a throw.
    case emptyResult
    /// The call failed for a reason worth retrying: rate limit, timeout,
    /// context overflow, guardrail trip.
    case generationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            "Couldn't break that down. Try again?"
        case .emptyResult:
            "Couldn't break that down. Try again?"
        case .generationFailed:
            "Couldn't break that down. Try again?"
        }
    }

    /// True when retrying the same request is worth a try. Drives whether the
    /// failure banner offers a button or just falls back to templates.
    var isRetryable: Bool {
        if case .generationFailed = self { return true }
        return false
    }
}
