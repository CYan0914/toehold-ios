import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// The on-device generator. Runs Apple's foundation model locally, which is why
/// this app can give AI breakdowns away for free while every competitor meters
/// theirs behind a subscription -- there is no per-request cost to pass on.
///
/// The availability gate is not a formality. The model needs a device that
/// supports Apple Intelligence *and* a supported region, and the supported
/// device list starts above the iPhone 15. On anything older,
/// `SystemLanguageModel.default.availability` reports `.unavailable` and this
/// type is never constructed -- `StepGeneratorFactory` routes those devices to
/// `TemplateStepGenerator` instead.
@available(iOS 26.0, *)
struct AIStepGenerator: StepGenerator {
    let source: StepSource = .ai

    func generateSteps(for title: String, category: CareScenario?) async throws -> [StepDraft] {
        #if canImport(FoundationModels)
        // Re-checked at call time, not just at construction. Apple Intelligence
        // can be switched off between one breakdown and the next, so a
        // generator built while the model was ready can be asked to run when it
        // is not. Throwing `.modelUnavailable` here (rather than a generic
        // failure) is what lets the caller fall back to templates instead of
        // showing an error.
        guard case .available = SystemLanguageModel.default.availability else {
            throw StepGeneratorError.modelUnavailable
        }

        let session = LanguageModelSession(instructions: Self.instructions)

        do {
            let response = try await session.respond(
                to: Self.prompt(for: title, category: category),
                generating: GeneratedStepList.self
            )
            let drafts = response.content.steps
                .map { StepDraft(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.text.isEmpty }

            guard !drafts.isEmpty else { throw StepGeneratorError.emptyResult }
            // The model is asked for 4-8 and usually complies, but a 30-step
            // answer is not a useful one, so the ceiling is enforced here
            // rather than trusted. The floor is not: padding a short list to
            // hit a count would add exactly the filler steps this app exists to
            // remove, and a 3-step answer is a fine answer.
            return Array(drafts.prefix(Self.maxSteps))
        } catch let error as StepGeneratorError {
            // Already in our vocabulary — `emptyResult` arrives here.
            throw error
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .assetsUnavailable:
                // The device says Apple Intelligence is on, but the model
                // weights are not actually on disk yet -- a fresh device still
                // downloading them, or a simulator that will never have them.
                // This is the availability check's blind spot: it reads the
                // feature flag, not the assets. Reporting it as retryable would
                // be a lie, because nothing the person does makes the download
                // finish, so it is mapped to the unavailability case and the
                // caller falls back to templates.
                throw StepGeneratorError.modelUnavailable
            default:
                throw StepGeneratorError.generationFailed(underlying: error)
            }
        } catch {
            // Anything else: rate limit, timeout, context overflow, guardrail
            // trip. `GenerationError` is @nonexhaustive so it cannot be
            // exhaustively switched over; the cases not named above do not
            // change what the caller should do, so they collapse into one
            // retryable case with the original attached for logging.
            throw StepGeneratorError.generationFailed(underlying: error)
        }
        #else
        // The framework is not in the SDK at all (older Xcode). Same outcome as
        // an unsupported device: this type is never reached in practice, since
        // the factory gates on availability first.
        throw StepGeneratorError.modelUnavailable
        #endif
    }

    /// 8, not 6. Someone paralysed enough to open this app benefits from the
    /// first three steps being nearly free; the ceiling only exists to stop a
    /// wall of text, and a wall starts around nine.
    static let maxSteps = 8

    /// The builder-closure form, which is the one Apple's own documentation
    /// demonstrates. `LanguageModelSession(instructions: """...""")` passes a
    /// bare string literal into this builder, so a literal inside the closure is
    /// a proven shape. A single-string `Instructions(_:)` may also exist but is
    /// not shown anywhere, and there is nothing to gain by being the first to
    /// rely on it.
    static let instructions = Instructions {
        """
        You break overwhelming tasks into steps so small they feel almost silly.

        The person asking is not lazy and does not need encouragement. They are \
        stuck — they know what to do and cannot make themselves start. Your job \
        is to make the first move so small that refusing it would be strange.

        Rules:
        - The first step takes under five seconds and is physical. "Stand up", \
        "Pick up the toothbrush", "Put your feet on the floor". Never "decide", \
        "plan", "think about", or "gather" — those are the things they are \
        already stuck on.
        - Every step is one action. If a step has an "and" in it, it is two steps.
        - No step asks them to find, choose, or remember anything.
        - Use plain words. No "begin", "proceed", "ensure", "utilise", "task".
        - Self-care tasks are as legitimate as work tasks. Brushing teeth, \
        showering, eating and taking medication get the same care as anything else.
        - Write the steps, not a preamble. No greeting, no explanation, no \
        closing encouragement.
        """
    }

    /// Built as one interpolated string rather than as two statements in a
    /// builder closure. Apple's own sample builds a `Prompt` from a single
    /// string; the multi-statement builder form also appears in their docs but
    /// is used there for conditional content, which this is not.
    static func prompt(for title: String, category: CareScenario?) -> Prompt {
        if let category {
            // The scenario carries intent the free text does not — someone who
            // tapped "Take a shower" wants the shower chain, not a literal
            // reading of four words.
            return Prompt(
                "Break this into steps: \(category.title). "
                + "They tapped the \(category.rawValue) category, so stay on that situation."
            )
        }
        return Prompt("Break this into steps: \(title)")
    }
}

#if canImport(FoundationModels)
/// The model's output shape. Declaring it as a `Generable` type rather than
/// parsing a text answer is what keeps the step list free of markdown bullets,
/// numbering and "Step 1:" prefixes — the model fills a field instead of
/// writing prose, so there is nothing to strip afterwards.
@available(iOS 26.0, *)
@Generable(description: "An ordered list of tiny steps for one task")
struct GeneratedStepList {
    @Guide(description: "Between 4 and 8 steps, in the order they should be done")
    var steps: [GeneratedStep]
}

@available(iOS 26.0, *)
@Generable(description: "A single step")
struct GeneratedStep {
    @Guide(description: "One action, under 8 words, no numbering or bullet character")
    var text: String
}
#endif

