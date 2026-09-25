import Foundation
import SwiftData

/// Fixed content for the screenshot run.
///
/// Every value here is chosen so the picture reads well at App Store size and
/// says something true about the product: the self-care scenarios lead, the
/// steps on screen are visibly tiny, and the history shows a mix of finished
/// and unfinished so the list is not a wall of green ticks.
///
/// Deliberately not random. A screenshot job that generates data each run
/// produces pictures that differ between runs, and the first time one of them
/// shows an odd state it is unreproducible.
@MainActor
enum DemoData {
    static func seed(into context: ModelContext) {
        let store = TaskStore(context: context)

        // The finished one, so the completion state has something behind it.
        let done = store.createTask(
            title: finishedTitle,
            drafts: CareScenarios.steps(for: .medication),
            source: .template,
            category: .medication
        )
        store.markComplete(done)

        // The in-progress one the runner screenshot opens on. Two steps ticked
        // rather than none, so the progress bar in the picture shows a bar
        // rather than an empty track.
        let shower = store.createTask(
            title: inProgressTitle,
            drafts: CareScenarios.steps(for: .shower),
            source: .template,
            category: .shower
        )
        for step in shower.orderedSteps.prefix(2) {
            _ = store.complete(step)
        }

        // A free-text one, so the history shows the AI path is not limited to
        // the eight tiles.
        _ = store.createTask(
            title: "Renew my passport",
            drafts: CareScenarios.fallbackSteps(for: "Renew my passport"),
            source: .ai,
            category: nil
        )

        // An untouched one, so the list is not all partial progress.
        _ = store.createTask(
            title: "Do the dishes",
            drafts: CareScenarios.steps(for: .dishes),
            source: .template,
            category: .dishes
        )
    }

    /// The task a demo screen should open on. Returns nil for `.home`.
    ///
    /// Screens are matched by title, not by position or by "first unfinished".
    /// `allTasks()` sorts newest first, so the newest unfinished task is the
    /// dishes -- an untouched chain, which is the opposite of what the runner
    /// and all-steps pictures are for. The comment that used to sit here said
    /// "the unfinished one with the most steps, which is the shower" and the
    /// code did not do that; two screens wanting different tasks is also why
    /// one lookup could not serve both.
    static func task(for screen: AppEnvironment.DemoScreen, in context: ModelContext) -> TaskItem? {
        let tasks = (try? TaskStore(context: context).allTasks()) ?? []
        switch screen {
        case .home:
            return nil
        case .allsteps, .runner:
            // The shower: two of thirteen steps ticked, so the progress bar in
            // the picture is a bar and the all-steps list shows both states.
            return tasks.first { $0.title == Self.inProgressTitle }
        case .done:
            return tasks.first { $0.title == Self.finishedTitle }
        }
    }

    // Titles are the join between `seed` and `task(for:)`. Declared once so a
    // reworded demo task cannot silently break which screen opens on what --
    // the failure mode is a screenshot job that succeeds while producing the
    // wrong picture, which no assertion in CI would catch.
    private static let finishedTitle = "Take my meds"
    private static let inProgressTitle = "Take a shower"
}
