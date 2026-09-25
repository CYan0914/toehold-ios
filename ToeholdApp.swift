import SwiftData
import SwiftUI

@main
struct ToeholdApp: App {
    /// One container for the app, built once.
    ///
    /// `isStoredInMemoryOnly: false` with the CloudKit configuration is the
    /// synced path. If the container cannot be built -- most likely a
    /// provisioning profile that is missing the iCloud entitlement -- the app
    /// falls back to a local-only store rather than crashing on launch. A
    /// person whose sync is broken should still be able to brush their teeth;
    /// refusing to open is a worse failure than not syncing, and the log line
    /// is what makes the difference findable.
    private let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            if let screen = AppEnvironment.demoScreen {
                // Screenshot runs get an in-memory store seeded with fixed
                // data. In-memory rather than the real container because a CI
                // runner may run this repeatedly, and accumulated demo tasks
                // would change the pictures between runs.
                DemoRootView(screen: screen)
                    .modelContainer(Self.demoContainer(fallback: container))
            } else {
                HomeView()
                    .modelContainer(container)
            }
        }
    }

    /// Seeded fresh per launch. The `seed` call happens in `DemoRootView`'s
    /// task rather than here, because `mainContext` is not safe to touch until
    /// the container is attached to the view tree.
    ///
    /// `fallback` is passed in rather than reaching for `container`: this is a
    /// static method and `container` is an instance property, so referring to it
    /// here does not compile.
    private static func demoContainer(fallback: ModelContainer) -> ModelContainer {
        let schema = Schema([TaskItem.self, StepItem.self])
        // Falls back to the real container if even an in-memory store fails,
        // which cannot happen in practice but keeps this init non-throwing.
        return (try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )) ?? fallback
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self, StepItem.self])

        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic
                )
            )
        } catch {
            assertionFailure("CloudKit-backed container failed, falling back to local: \(error)")
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        cloudKitDatabase: .none
                    )
                )
            } catch {
                // Neither store opened. There is nothing left to degrade to, so
                // an in-memory store keeps the app usable for the session and
                // the assertion above is the trail.
                assertionFailure("Local container failed too, using in-memory: \(error)")
                // `try!` is deliberate and the only one in the app: an in-memory
                // container with no schema constraints cannot fail, and if it
                // somehow does, there is no further fallback to write.
                return try! ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                )
            }
        }
    }
}
