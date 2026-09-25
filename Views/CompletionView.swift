import SwiftUI

/// What the person sees when the last step is ticked.
///
/// Separate from the runner because it is the one screen in the app with a job
/// other than "show the next thing": it has to end the interaction. Everything
/// before it is deliberately stripped of praise, so this is the only place the
/// app is allowed to say something warm -- and it still does not say "great
/// job". Someone who needed help brushing their teeth does not need applause
/// for it, and the count is the interesting fact, not the congratulations.
struct CompletionView: View {
    let task: TaskItem
    /// Drives the bounce. Owned by the runner, which knows whether the last
    /// step was ticked just now or the screen was reopened on an already
    /// finished task -- the second case must not animate, or reopening a
    /// finished task replays a celebration for something done last week.
    let animate: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: animate)

            Text("That's it")
                .font(.system(size: 32, weight: .semibold, design: .rounded))

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Singular and plural are both spelled out rather than built from a
    /// template. "1 steps, done." is the kind of thing that survives review
    /// because it only shows up on the shortest tasks -- which are exactly the
    /// tasks this app is for, so it would be seen constantly.
    private var summary: String {
        let count = task.orderedSteps.count
        if count == 0 { return "Done." }
        if count == 1 { return "One step, done." }
        return "\(count) steps, done."
    }
}
