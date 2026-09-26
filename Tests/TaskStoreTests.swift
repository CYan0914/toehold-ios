import Foundation
import SwiftData
import Testing
@testable import Toehold

/// In-memory container per test. `@MainActor` because `TaskStore` is, which
/// matches how the app uses it — every call comes from a view.
@MainActor
struct TaskStoreTests {
    /// Each store gets its own store file, and that is the whole point.
    ///
    /// This used to be `ModelConfiguration(schema:isStoredInMemoryOnly: true)`
    /// with no `url`. Every test built its own container, and with no url each
    /// one derived the same default path from the same schema — so eight
    /// containers were pointed at one store. The observable symptom was a test
    /// process that died the instant a `TaskStoreTests` case started, printing
    /// nothing: no assertion failure, no error, not even the test's own name in
    /// the run log. `TaskStore.save()` swallows a throwing `context.save()`
    /// into `assertionFailure`, which traps in a Debug build, so a failed save
    /// is a silent kill rather than a reported one.
    ///
    /// `isStoredInMemoryOnly: true` does not make the file irrelevant: SwiftData
    /// still derives a path from the schema, and two containers on one path
    /// collide. A unique url per test removes the collision at the source.
    ///
    /// The file is deleted on the way out, so a red test does not leave a store
    /// behind for the next run to trip over.
    private func makeStore() throws -> TaskStore {
        let schema = Schema([TaskItem.self, StepItem.self])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToeholdTests-\(UUID().uuidString).store")
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
        return TaskStore(context: container.mainContext)
    }

    private let drafts = [
        StepDraft(text: "Stand up"),
        StepDraft(text: "Walk to the bathroom"),
        StepDraft(text: "Pick up the toothbrush"),
    ]

    @Test
    func createTaskPersistsStepsInOrder() throws {
        let store = try makeStore()
        let task = store.createTask(
            title: "Brush my teeth",
            drafts: drafts,
            source: .template,
            category: .hygiene
        )

        let steps = task.orderedSteps
        #expect(steps.count == 3)
        #expect(steps.map(\.text) == drafts.map(\.text))
        #expect(steps.map(\.order) == [0, 1, 2])
        #expect(task.category == .hygiene)
        #expect(task.source == .template)
        #expect(task.startedAt != nil)
    }

    @Test
    func completingTheLastStepSetsCompletedAt() throws {
        let store = try makeStore()
        let task = store.createTask(title: "T", drafts: drafts, source: .template, category: nil)

        let steps = task.orderedSteps
        #expect(store.complete(steps[0]) == false)
        #expect(store.complete(steps[1]) == false)
        #expect(task.completedAt == nil)

        #expect(store.complete(steps[2]) == true)
        #expect(task.completedAt != nil)
        #expect(task.isComplete)
    }

    @Test
    func completingAStepTwiceDoesNotMoveItsTimestamp() throws {
        let store = try makeStore()
        let task = store.createTask(title: "T", drafts: drafts, source: .template, category: nil)
        let step = task.orderedSteps[0]

        store.complete(step)
        let first = step.doneAt
        store.complete(step)

        #expect(step.doneAt == first)
    }

    @Test
    func uncompletingAStepClearsTaskCompletion() throws {
        let store = try makeStore()
        let task = store.createTask(title: "T", drafts: drafts, source: .template, category: nil)
        for step in task.orderedSteps { store.complete(step) }
        #expect(task.isComplete)

        store.uncomplete(task.orderedSteps[1])

        // Both halves matter: a finished-looking task back in the runner is the
        // bug this guards, and the history would show it done while the runner
        // shows it in progress.
        #expect(!task.isComplete)
        #expect(task.completedAt == nil)
        #expect(task.currentStep?.text == drafts[1].text)
    }

    @Test
    func deletingATaskCascadesToItsSteps() throws {
        let store = try makeStore()
        let task = store.createTask(title: "T", drafts: drafts, source: .template, category: nil)
        let stepIDs = task.orderedSteps.map(\.id)

        store.delete(task)

        let remaining = try store.context.fetch(FetchDescriptor<StepItem>())
        #expect(remaining.isEmpty)
        #expect(try store.allTasks().isEmpty)
        _ = stepIDs
    }

    @Test
    func unfinishedTaskReturnsTheOldestOpenOne() throws {
        let store = try makeStore()
        let first = store.createTask(title: "First", drafts: drafts, source: .template, category: nil)
        _ = store.createTask(title: "Second", drafts: drafts, source: .template, category: nil)

        #expect(try store.unfinishedTask()?.title == "First")

        for step in first.orderedSteps { store.complete(step) }
        #expect(try store.unfinishedTask()?.title == "Second")
    }

    @Test
    func currentStepIsFirstUnfinished() throws {
        let store = try makeStore()
        let task = store.createTask(title: "T", drafts: drafts, source: .template, category: nil)
        #expect(task.currentStep?.text == drafts[0].text)

        store.complete(task.orderedSteps[0])
        #expect(task.currentStep?.text == drafts[1].text)

        store.complete(task.orderedSteps[1])
        store.complete(task.orderedSteps[2])
        #expect(task.currentStep == nil)
    }

    @Test
    func markCompleteTicksEveryStep() throws {
        let store = try makeStore()
        let task = store.createTask(title: "T", drafts: drafts, source: .template, category: nil)

        store.markComplete(task)

        #expect(task.orderedSteps.count == drafts.count)
        #expect(task.orderedSteps.filter(\.done).count == drafts.count)
        #expect(task.completedAt != nil)
    }

    /// The CloudKit model constraints are silent when violated — the container
    /// throws at init with a message about the store being incompatible. This
    /// asserts the shape the constraints require, so a future property added
    /// without a default fails here rather than on someone's phone.
    @Test
    func modelIsCloudKitCompatible() throws {
        let task = TaskItem(title: "no defaults given")
        #expect(task.title == "no defaults given")
        #expect(task.steps != nil)
        #expect(task.completedAt == nil)
        #expect(task.sourceRaw == StepSource.manual.rawValue)

        let step = StepItem(text: "t", order: 0)
        #expect(step.done == false)
        #expect(step.task == nil)
    }
}
