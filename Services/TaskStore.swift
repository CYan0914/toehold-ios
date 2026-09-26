import Foundation
import SwiftData

/// Every write the app makes, in one place.
///
/// The views do not touch `ModelContext` directly. Two reasons: the completion
/// rule below has to be applied uniformly or a task can end up finished with
/// `completedAt` never written, and every mutation here is a place CloudKit can
/// fail, so having them in one file makes the error handling reviewable.
@MainActor
final class TaskStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Creating

    /// Creates a task and its steps from a fresh breakdown.
    ///
    /// `startedAt` is set here rather than when the runner opens, because the
    /// person has already started by asking for the breakdown -- treating the
    /// ask as not-yet-started loses the timestamp for the exact case that
    /// matters most, someone who asked, read the list, and put the phone down.
    @discardableResult
    func createTask(
        title: String,
        drafts: [StepDraft],
        source: StepSource,
        category: CareScenario?
    ) -> TaskItem {
        let task = TaskItem(title: title, source: source, category: category)
        task.startedAt = Date()
        context.insert(task)

        for (index, draft) in drafts.enumerated() {
            let step = StepItem(text: draft.text, order: index)
            step.task = task
            context.insert(step)
        }

        save()
        return task
    }

    // MARK: - Running

    /// Ticks a step off. Returns true when that was the last one, so the caller
    /// knows to show the completion screen without re-deriving it.
    ///
    /// Idempotent: ticking an already-done step reports whether the task is
    /// finished without moving `doneAt`. Double-taps on a big button are
    /// normal, and rewriting the timestamp would make the history's durations
    /// depend on how fast someone's thumb was.
    @discardableResult
    func complete(_ step: StepItem) -> Bool {
        guard !step.done else { return isFinished(step.task) }

        step.done = true
        step.doneAt = Date()

        let task = step.task
        if isFinished(task) {
            task?.completedAt = Date()
        }
        save()
        return isFinished(task)
    }

    /// Un-ticks a step and clears the task's completion.
    ///
    /// Both halves matter: leaving `completedAt` set after a step is reopened
    /// puts a finished-looking task back in the runner, and the history list
    /// would show it as done while the runner shows it as in progress.
    func uncomplete(_ step: StepItem) {
        step.done = false
        step.doneAt = nil
        step.task?.completedAt = nil
        save()
    }

    /// Marks a task finished without walking the remaining steps. For the
    /// person who did the thing offline and is closing the loop, which is a
    /// more common ending than tapping the last step in the app.
    func markComplete(_ task: TaskItem) {
        let now = Date()
        for step in task.orderedSteps where !step.done {
            step.done = true
            step.doneAt = now
        }
        task.completedAt = now
        save()
    }

    // MARK: - Deleting

    func delete(_ task: TaskItem) {
        // Steps go with it through the `.cascade` rule, but only if SwiftData
        // sees them as related -- which requires the relationship to be
        // populated. Deleting through the task rather than deleting steps
        // individually is what keeps that true.
        context.delete(task)
        save()
    }

    func delete(_ step: StepItem) {
        // Removing a middle step leaves a gap in `order`, which is fine:
        // nothing reads `order` as a contiguous sequence, only as a sort key.
        context.delete(step)
        save()
    }

    // MARK: - Querying

    /// Most recent first, for the history list.
    func allTasks() throws -> [TaskItem] {
        var descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.steps]
        return try context.fetch(descriptor)
    }

    /// The task the home screen offers to resume: started and never finished,
    /// oldest first so the one that has been hanging longest surfaces.
    func unfinishedTask() throws -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.completedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        descriptor.relationshipKeyPathsForPrefetching = [\.steps]
        return try context.fetch(descriptor).first
    }

    // MARK: - Saving

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // A failed save with CloudKit configured is usually the network,
            // and SwiftData retries on the next change. Surfacing an alert here
            // would put an error in front of someone mid-task for something
            // that resolves itself, so the person is not interrupted.
            //
            // It is logged rather than asserted. `assertionFailure` traps in a
            // Debug build, which is the build the tests run: a container that
            // could not save killed the test process before it could report
            // anything, so eight failing tests presented as one silent crash
            // with no failing test named. A log line lets the run finish and
            // say what went wrong.
            print("SwiftData save failed: \(error)")
        }
    }

    private func isFinished(_ task: TaskItem?) -> Bool {
        guard let task else { return false }
        let steps = task.orderedSteps
        return !steps.isEmpty && steps.allSatisfy(\.done)
    }
}
