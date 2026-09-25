import Foundation
import SwiftData

/// A thing the person is trying to start, plus the steps it was broken into.
///
/// Every property here has a default value or is optional, and that is a
/// CloudKit requirement rather than a style choice. CloudKit syncs by field,
/// so a non-optional property with no default cannot be materialised on a
/// second device that receives a partial record -- the container fails to
/// initialise and the app crashes on launch with a message about the model
/// being incompatible with the store. Same reason there is no
/// `@Attribute(.unique)` here: uniqueness is not expressible across devices
/// without a coordinator, so SwiftData rejects it at container setup.
@Model
final class TaskItem {
    var id: UUID = UUID()

    /// What the person typed, verbatim. Kept as typed rather than normalised,
    /// because the history list reads better showing their own words back.
    var title: String = ""

    var createdAt: Date = Date()

    /// Set when the person opens the step runner. Distinct from `completedAt`
    /// because the interesting case in this app is a task that was started and
    /// never finished -- that is the one worth surfacing again, and it is
    /// invisible if the only timestamps are created and completed.
    var startedAt: Date?

    var completedAt: Date?

    /// Stored as a raw string because SwiftData predicates cannot filter on an
    /// enum with an associated value, and the history list does filter on this.
    /// Use `source` to read it; the raw value is an implementation detail.
    var sourceRaw: String = StepSource.manual.rawValue

    /// Self-care scenario tag, e.g. "hygiene". Nil for free-text tasks.
    var categoryRaw: String?

    /// `.cascade` rather than `.nullify`: a step has no meaning without its
    /// task, and orphaned StepItem rows accumulate silently otherwise. The
    /// array is optional because CloudKit requires to-many relationships to be
    /// optional -- a non-optional empty array is not representable in a
    /// partial record.
    @Relationship(deleteRule: .cascade, inverse: \StepItem.task)
    var steps: [StepItem]? = []

    init(
        title: String,
        source: StepSource = .manual,
        category: CareScenario? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.sourceRaw = source.rawValue
        self.categoryRaw = category?.rawValue
        self.steps = []
    }

    var source: StepSource {
        get { StepSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var category: CareScenario? {
        get { categoryRaw.flatMap(CareScenario.init(rawValue:)) }
        set { categoryRaw = newValue?.rawValue }
    }

    /// Ordered by `order` rather than by insertion, because CloudKit does not
    /// guarantee that the array arrives in the order it was written. Reading
    /// `steps` directly would show a shuffled list on a synced device and the
    /// correct one locally, which is the kind of bug that only reproduces on
    /// someone else's phone.
    var orderedSteps: [StepItem] {
        (steps ?? []).sorted { $0.order < $1.order }
    }

    var isComplete: Bool { completedAt != nil }

    /// 0...1, for the progress bar in the runner.
    var progress: Double {
        let all = orderedSteps
        guard !all.isEmpty else { return 0 }
        return Double(all.filter(\.done).count) / Double(all.count)
    }

    /// The step to show right now: the first one not yet done, or nil when the
    /// list is finished. Nil and "all done" are the same condition on purpose --
    /// a task whose steps were all ticked off but whose `completedAt` never got
    /// written (app killed mid-run) reads as complete here rather than as a
    /// task with nothing left to show.
    var currentStep: StepItem? {
        orderedSteps.first { !$0.done }
    }
}
