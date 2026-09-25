import SwiftData
import SwiftUI

/// The one screen a person has to understand: type the thing you cannot start,
/// or tap the tile for a situation you already know you are stuck on.
///
/// There is no empty state with an illustration and a paragraph explaining the
/// product. Someone who cannot start brushing their teeth will not read it, and
/// the time between opening the app and seeing a first step is the metric this
/// screen exists to protect.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @State private var typed = ""
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var path: [TaskItem] = []
    @FocusState private var isFieldFocused: Bool

    private var store: TaskStore { TaskStore(context: modelContext) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    prompt
                    ScenarioPickerView { scenario in
                        start(title: scenario.title, category: scenario)
                    }
                    history
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Toehold")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TaskItem.self) { task in
                StepRunnerView(task: task)
            }
            .overlay {
                if isGenerating { generatingOverlay }
            }
        }
    }

    // MARK: - Sections

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What can't you start?")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                TextField("Brush my teeth", text: $typed)
                    .textFieldStyle(.plain)
                    .submitLabel(.go)
                    .focused($isFieldFocused)
                    .onSubmit { submitTyped() }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))

                Button(action: submitTyped) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(canSubmit ? Color.accentColor : Color(.tertiarySystemFill), in: .circle)
                        .foregroundStyle(canSubmit ? .white : Color(.tertiaryLabel))
                }
                .disabled(!canSubmit)
                .accessibilityLabel("Break it into steps")
            }

            if let generationError {
                Text(generationError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Earlier")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if tasks.isEmpty {
                Text("Nothing yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        Button {
                            path.append(task)
                        } label: {
                            TaskRow(task: task)
                        }
                        .buttonStyle(.plain)
                        // Long-press to delete, not swipe and not an Edit button.
                        //
                        // The rows live in a `LazyVStack` inside this screen's
                        // `ScrollView`, because the prompt and the scenario strip
                        // have to scroll with them. `.onDelete` and
                        // `swipeActions` are both consumed by `List` only: in
                        // this container they compile and do nothing at all, so
                        // the row would look deletable and never delete. A
                        // context menu is the affordance that works here.
                        //
                        // Delete is not confirmed, and that is a deliberate
                        // trade. The list is a record of small daily things, not
                        // of anything that took work to enter, and a confirmation
                        // on every row makes tidying the list a chore. The row's
                        // title is in the menu's label, so the target is visible
                        // at the moment of the tap.
                        .contextMenu {
                            Button(role: .destructive) {
                                store.delete(task)
                            } label: {
                                Label("Delete \"\(task.title)\"", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var generatingOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(0.6).ignoresSafeArea()
            ProgressView("Breaking it down")
                .padding(24)
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private var canSubmit: Bool {
        !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    private func submitTyped() {
        let title = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isFieldFocused = false
        start(title: title, category: nil)
    }

    /// Generates steps, then pushes the runner.
    ///
    /// The template path is tried as a fallback rather than as an alternative,
    /// so a model failure never costs the person the interaction — they get
    /// steps either way, and the only difference is which generator produced
    /// them. That is the whole reason the two generators sit behind one
    /// protocol.
    private func start(title: String, category: CareScenario?) {
        guard !isGenerating else { return }
        generationError = nil
        isGenerating = true

        Task {
            let generator = StepGeneratorFactory.make()
            var drafts: [StepDraft] = []
            var source = generator.source

            do {
                drafts = try await generator.generateSteps(for: title, category: category)
            } catch {
                // Any failure, including the model going unavailable mid-flight,
                // lands here. Templates always answer, so this is a fallback
                // rather than an error path — the person gets steps either way
                // and only the recorded source differs.
                let fallback = TemplateStepGenerator()
                drafts = (try? await fallback.generateSteps(for: title, category: category)) ?? []
                source = fallback.source
                if drafts.isEmpty {
                    generationError = "Couldn't break that down. Try again?"
                }
            }

            isGenerating = false

            guard !drafts.isEmpty else { return }
            let task = store.createTask(
                title: title,
                drafts: drafts,
                source: source,
                category: category
            )
            typed = ""
            path.append(task)
        }
    }

}

/// One row in the history list. Kept separate so the button wrapper in
/// `history` stays a plain tap target and this can grow.
private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(task.isComplete ? Color.accentColor : Color(.tertiaryLabel), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if task.isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Circle()
                        .trim(from: 0, to: task.progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private var subtitle: String {
        let steps = task.orderedSteps
        if task.isComplete {
            return "Done · \(steps.count) steps"
        }
        let remaining = steps.filter { !$0.done }.count
        return remaining == 1 ? "1 step left" : "\(remaining) steps left"
    }
}
