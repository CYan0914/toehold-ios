import Foundation

/// The built-in step chains for the devices that cannot run the on-device
/// model, and for the moments when the model is available but the person picked
/// a scenario tile instead of typing.
///
/// The steps are written to be absurdly small, and that is the whole point.
/// "Stand up" is a real step. So is "walk to the bathroom". A list that reads
/// like a sensible task breakdown -- "Gather your toothbrush and toothpaste,
/// brush for two minutes, rinse" -- is a list a person who is already stuck
/// will read and still not start, because the first item is three decisions
/// wearing a sentence.
///
/// Two rules for anything added here:
///   1. The first step is physical and takes under five seconds. It is the
///      answer to "I can't start", so it cannot itself require starting.
///   2. No step contains "and". A step with an "and" is two steps.
enum CareScenarios {
    static func steps(for scenario: CareScenario) -> [StepDraft] {
        chain(for: scenario).map(StepDraft.init(text:))
    }

    /// Used when someone types something the template path has no chain for.
    /// Deliberately generic rather than clever: an opener that works for any
    /// task beats a wrong guess dressed up as a specific one.
    static func fallbackSteps(for title: String) -> [StepDraft] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = trimmed.isEmpty ? "it" : trimmed
        return [
            StepDraft(text: "Put down whatever is in your hands"),
            StepDraft(text: "Say out loud: \"\(subject)\""),
            StepDraft(text: "Do the smallest possible piece of it"),
            StepDraft(text: "Do one more piece"),
            // Ends the chain on a physical act, not on a decision. The obvious
            // closer ("decide if you're done") is the exact move the first step
            // exists to avoid, and putting it last does not make it cheaper --
            // it is still a question the person has to answer.
            StepDraft(text: "Put it away"),
        ]
    }

    private static func chain(for scenario: CareScenario) -> [String] {
        switch scenario {
        case .hygiene:
            [
                "Stand up",
                "Walk to the bathroom",
                "Pick up the toothbrush",
                "Put toothpaste on it",
                "Brush the top teeth",
                "Brush the bottom teeth",
                "Spit",
                "Rinse the brush",
            ]
        case .shower:
            [
                "Stand up",
                "Walk to the bathroom",
                "Turn the water on",
                "Take off one thing",
                "Take off one more thing",
                "Get in",
                "Wet your hair",
                "Wash your hair",
                "Wash your body",
                "Rinse off",
                "Turn the water off",
                "Get out",
                "Dry off",
            ]
        case .medication:
            [
                "Stand up",
                "Walk to where the pills are",
                "Open the bottle",
                "Take one out",
                "Get a glass of water",
                "Swallow it",
                "Put the bottle back",
            ]
        case .wakingUp:
            [
                "Move one foot",
                "Put both feet on the floor",
                "Sit up",
                "Stand up",
                "Walk to the kitchen",
                "Drink some water",
            ]
        case .eating:
            [
                "Stand up",
                "Walk to the kitchen",
                "Open the fridge",
                "Take out one thing you can eat",
                "Put it on the counter",
                "Eat one bite",
                "Eat one more bite",
                "Put the rest away",
            ]
        case .dishes:
            [
                "Stand up",
                "Walk to the sink",
                "Turn the water on",
                "Pick up one dish",
                "Rinse it",
                "Put it in the rack",
                "Pick up one more dish",
                "Stop whenever you want",
            ]
        case .laundry:
            [
                "Stand up",
                "Pick up one thing off the floor",
                "Put it in the basket",
                "Pick up one more thing",
                "Carry the basket to the machine",
                "Open the machine",
                "Put the basket down next to it",
            ]
        case .leavingHome:
            [
                "Stand up",
                "Put on your shoes",
                "Pick up your keys",
                "Pick up your phone",
                "Walk to the door",
                "Open the door",
                "Step outside",
                "Close the door",
            ]
        }
    }
}
