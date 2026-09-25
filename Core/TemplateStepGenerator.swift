import Foundation

/// The generator for devices without Apple Intelligence, and the one that
/// answers instantly when a scenario tile is tapped on a device that has it.
///
/// Never throws. The whole reason this type exists is that a person on an older
/// phone must not hit a failure path the AI path would not have hit -- a
/// "couldn't generate steps" alert on a phone that simply cannot run the model
/// is the app admitting it does not support them.
struct TemplateStepGenerator: StepGenerator {
    let source: StepSource = .template

    func generateSteps(for title: String, category: CareScenario?) async throws -> [StepDraft] {
        if let category {
            return CareScenarios.steps(for: category)
        }
        // No tile was picked, so try to read the typed text as one of the
        // known situations before giving up on specificity.
        if let matched = Self.match(title) {
            return CareScenarios.steps(for: matched)
        }
        return CareScenarios.fallbackSteps(for: title)
    }

    /// Keyword match from the typed title to a scenario.
    ///
    /// Word-boundary matching rather than `contains`, and the distinction is
    /// not pedantic: `contains("eat")` fires on "brush my teeth", and a person
    /// who typed "teeth" then gets handed the eating chain. Longest keyword
    /// first, because "shower" and "hair wash" both appear in some phrasings
    /// and the more specific one should win.
    static func match(_ title: String) -> CareScenario? {
        let words = Set(
            title.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )
        guard !words.isEmpty else { return nil }

        for (scenario, keywords) in keywordTable {
            if keywords.contains(where: { words.contains($0) }) {
                return scenario
            }
        }
        return nil
    }

    /// Ordered by specificity: the entries whose keywords are less likely to
    /// appear in an unrelated sentence come first. `wakingUp` last.
    ///
    /// Keywords are nouns where a noun exists, and that is a rule rather than a
    /// preference. Two verbs had to come out because of it:
    ///
    ///   * "up" was in the waking list, since "get up" and "wake up" are the
    ///     obvious phrasings. It is a particle, not a word with meaning on its
    ///     own, and it appears in phrasal verbs everywhere: "clean up the
    ///     kitchen" matched `wakingUp` and offered "Put both feet on the floor"
    ///     for a sink full of dishes.
    ///   * "wash" was in the shower list. "wash up the plates" matched it and
    ///     got the shower chain; the plates were never going to get done.
    ///
    /// What each costs: a bare "get up" and a bare "wash my face" now fall
    /// through to the generic chain. That is a worse answer than the right
    /// chain and a much better one than the wrong chain, and the phrasing that
    /// actually identifies the task ("wake up", "shower", "wash my hair",
    /// "wash the dishes") still matches on its own noun.
    private static let keywordTable: [(CareScenario, Set<String>)] = [
        (.hygiene, ["teeth", "toothbrush", "brush", "toothpaste", "floss"]),
        (.shower, ["shower", "bathe", "bath", "hair"]),
        (.medication, ["meds", "medication", "medicine", "pills", "pill", "prescription"]),
        (.dishes, ["dishes", "dish", "sink", "plates"]),
        (.laundry, ["laundry", "washing", "washer", "clothes", "basket"]),
        (.leavingHome, ["leave", "leaving", "outside", "keys", "door", "shoes"]),
        (.eating, ["eat", "eating", "food", "meal", "lunch", "dinner", "breakfast", "cook"]),
        (.wakingUp, ["bed", "wake", "waking", "morning", "alarm"]),
    ]
}
