import SwiftData
import SwiftUI

/// The step runner. One step on screen at a time, and that is the entire
/// design: the failure this app addresses is seeing a list and freezing, so
/// showing the list again inside the runner would reintroduce the problem at
/// the exact moment the person is trying to move past it.
///
/// The remaining count is shown as a small progress bar rather than as text
/// ("3 of 8"). A number is a reminder of how much is left; a bar that is
/// visibly two-thirds full is a reminder of how much is done.
struct StepRunnerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let task: TaskItem

    @State private var justFinished = false
    @State private var showAllSteps = false

    private var store: TaskStore { TaskStore(context: modelContext) }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            Spacer(minLength: 0)

            if let step = task.currentStep {
                currentStepBody(step)
            } else {
                CompletionView(task: task, animate: justFinished)
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAllSteps = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Show all steps")
            }
        }
        .sheet(isPresented: $showAllSteps) {
            StepListView(task: task)
        }
        .onAppear {
            // A task opened from history may never have been started — created
            // on another device, or restored from a backup. Stamping it here
            // covers the paths that did not go through the home screen.
            if task.startedAt == nil {
                task.startedAt = Date()
            }
        }
    }

    // MARK: - Sections

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: task.progress)
                .tint(.accentColor)
            HStack {
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if task.source == .ai {
                    Label("On-device", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 12)
    }

    private func currentStepBody(_ step: StepItem) -> some View {
        VStack(spacing: 32) {
            Text(step.text)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .id(step.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Button {
                advance(from: step)
            } label: {
                Text("Done")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.accentColor, in: .rect(cornerRadius: 18))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        HStack {
            if task.currentStep != nil {
                Button("Skip this one") {
                    if let step = task.currentStep { advance(from: step, skipped: true) }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if task.isComplete {
                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.medium))
            }
        }
        .frame(height: 32)
    }

    private var statusLine: String {
        let all = task.orderedSteps
        let done = all.filter(\.done).count
        if all.isEmpty { return "" }
        if done == all.count { return "All done" }
        return "Step \(done + 1) of \(all.count)"
    }

    // MARK: - Actions

    /// Marks the step and moves on.
    ///
    /// The completion screen is reached by `task.currentStep` becoming nil, not
    /// by a flag — so killing the app on the last step and reopening it still
    /// shows the task as finished, because the last step is genuinely ticked.
    private func advance(from step: StepItem, skipped: Bool = false) {
        withAnimation(.snappy) {
            if skipped {
                // "Skip" means "not now", not "done". The step stays unticked
                // and moves to the back of the queue by taking a higher `order`
                // than everything else — marking it done would quietly lie in
                // the history about what got accomplished, and leaving it in
                // place would make the button appear to do nothing.
                let steps = task.orderedSteps
                let maxOrder = steps.map(\.order).max() ?? 0
                // Only reorder when there is something after it; skipping the
                // last open step should NOT make it the new current step,
                // because that is a no-op the person would read as broken.
                if steps.contains(where: { !$0.done && $0.order > step.order }) {
                    step.order = maxOrder + 1
                }
            } else {
                justFinished = store.complete(step)
            }
        }
    }
}

/// The full list, behind the toolbar button. Available for the person who wants
/// to see the shape of the task before starting — but never the default view,
/// because that is the view that stops people.
///
/// Not `private`, so the screenshot host in `DemoRootView` can present it
/// directly. Presenting it there rather than pushing the runner and tapping the
/// toolbar button is the difference between a picture of this screen and a
/// picture of whatever the automation happened to hit.
struct StepListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let task: TaskItem

    private var store: TaskStore { TaskStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(task.orderedSteps) { step in
                    Button {
                        if step.done {
                            store.uncomplete(step)
                        } else {
                            _ = store.complete(step)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.done ? Color.accentColor : Color(.tertiaryLabel))
                            Text(step.text)
                                .strikethrough(step.done, color: .secondary)
                                .foregroundStyle(step.done ? .secondary : .primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let steps = task.orderedSteps
                    for index in offsets { store.delete(steps[index]) }
                }
            }
            .navigationTitle("All steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
