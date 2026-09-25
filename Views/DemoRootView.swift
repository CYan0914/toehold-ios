import SwiftData
import SwiftUI

/// Opens straight onto the screen the screenshot job asked for, with demo data
/// already in the store. Only reachable via the `-ToeholdDemo` launch argument.
///
/// The seeding happens in `.task` rather than in an initialiser because the
/// container is not attached to the environment until the view appears, and
/// `mainContext` is only safe to touch once it is. `didSeed` guards against a
/// second run from a view identity change, which would double every task.
struct DemoRootView: View {
    @Environment(\.modelContext) private var modelContext

    let screen: AppEnvironment.DemoScreen

    @State private var didSeed = false
    @State private var task: TaskItem?

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView()
            case .runner, .done:
                if let task {
                    NavigationStack {
                        StepRunnerView(task: task)
                    }
                } else {
                    HomeView()
                }
            case .allsteps:
                if let task {
                    NavigationStack {
                        StepListSheetHost(task: task)
                    }
                } else {
                    HomeView()
                }
            }
        }
        .task {
            guard !didSeed else { return }
            didSeed = true
            DemoData.seed(into: modelContext)
            task = DemoData.task(for: screen, in: modelContext)
        }
    }
}

/// The all-steps list is a sheet in the real app, so a screenshot of it needs
/// the sheet presented rather than the list pushed. This hosts it open over
/// the runner, which is the stack it appears over in the app.
struct StepListSheetHost: View {
    let task: TaskItem

    @State private var presented = false

    var body: some View {
        StepRunnerView(task: task)
            .task {
                // A beat after the runner settles, so the sheet animates in
                // over a drawn screen instead of a blank one.
                try? await Task.sleep(for: .milliseconds(400))
                presented = true
            }
            .sheet(isPresented: $presented) {
                StepListView(task: task)
            }
    }
}
