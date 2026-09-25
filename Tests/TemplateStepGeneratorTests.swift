import Testing
@testable import Toehold

/// The template path is the one every device can reach, including the phones
/// that cannot run the model. A bug here is a bug for the entire install base,
/// so these cover every scenario rather than a sample.
struct TemplateStepGeneratorTests {
    let generator = TemplateStepGenerator()

    @Test(arguments: CareScenario.allCases)
    func everyScenarioProducesSteps(scenario: CareScenario) async throws {
        let steps = try await generator.generateSteps(for: scenario.title, category: scenario)
        #expect(!steps.isEmpty)
        #expect(steps.allSatisfy { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    @Test(arguments: CareScenario.allCases)
    func firstStepIsImmediate(scenario: CareScenario) async throws {
        let steps = try await generator.generateSteps(for: scenario.title, category: scenario)
        let first = try #require(steps.first?.text)
        // The first step is the answer to "I can't start", so it cannot itself
        // be a decision or a search. These are the words that turn a step back
        // into the problem.
        for verb in ["decide", "plan", "think", "gather", "find", "choose", "remember"] {
            #expect(!first.lowercased().contains(verb))
        }
    }

    @Test(arguments: CareScenario.allCases)
    func noStepContainsAnd(scenario: CareScenario) async throws {
        let steps = try await generator.generateSteps(for: scenario.title, category: scenario)
        // "X and Y" is two steps wearing one sentence, which is the exact
        // failure mode this app exists to avoid.
        #expect(steps.allSatisfy { !$0.text.lowercased().contains(" and ") })
    }

    /// The rule applies to every step, not only the first.
    ///
    /// It has to: a decision in the middle of a chain strands the person just
    /// as effectively as one at the start, and a chain whose last step is
    /// "decide if you're done" leaves them holding the same question they
    /// opened the app with. The per-scenario test above only ever checked
    /// `first`, so a "decide" step further down was invisible to it -- which is
    /// how one reached the fallback chain.
    @Test(arguments: CareScenario.allCases)
    func noStepIsADecision(scenario: CareScenario) async throws {
        let steps = try await generator.generateSteps(for: scenario.title, category: scenario)
        for step in steps {
            for verb in ["decide", "plan", "think", "gather", "find", "choose", "remember"] {
                #expect(
                    !step.text.lowercased().contains(verb),
                    "\(scenario.rawValue): \"\(step.text)\" contains \"\(verb)\""
                )
            }
        }
    }

    @Test
    func fallbackStepsAreAlsoDecisionFree() async throws {
        let steps = try await generator.generateSteps(for: "renew my passport", category: nil)
        for step in steps {
            for verb in ["decide", "plan", "think", "gather", "find", "choose", "remember"] {
                #expect(
                    !step.text.lowercased().contains(verb),
                    "fallback: \"\(step.text)\" contains \"\(verb)\""
                )
            }
        }
    }

    /// No chain repeats a step.
    ///
    /// Not hypothetical: `wakingUp` shipped with "Put your feet on the ground"
    /// two lines after "Put both feet on the floor". A repeat reads as a bug to
    /// the person tapping through it and makes the progress bar look wrong at
    /// the end, since the count no longer matches what they did.
    @Test(arguments: CareScenario.allCases)
    func noScenarioRepeatsAStep(scenario: CareScenario) async throws {
        let texts = try await generator.generateSteps(for: scenario.title, category: scenario)
            .map(\.text)
        #expect(Set(texts).count == texts.count, "\(scenario.rawValue) repeats a step")
    }

    @Test
    func unknownTitleFallsBackToGenericSteps() async throws {
        let steps = try await generator.generateSteps(
            for: "renew my passport",
            category: nil
        )
        #expect(!steps.isEmpty)
        // The fallback echoes the title back in the second step. That is the
        // point: it proves the input reached the generator rather than being
        // dropped.
        #expect(steps.contains { $0.text.contains("renew my passport") })
    }

    @Test
    func emptyTitleDoesNotProduceEmptyStep() async throws {
        let steps = try await generator.generateSteps(for: "   ", category: nil)
        #expect(steps.allSatisfy { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    // MARK: - Keyword matching

    @Test
    func matchesKnownSituations() {
        #expect(TemplateStepGenerator.match("brush my teeth") == .hygiene)
        #expect(TemplateStepGenerator.match("I need to shower") == .shower)
        #expect(TemplateStepGenerator.match("take my meds") == .medication)
        #expect(TemplateStepGenerator.match("do the dishes") == .dishes)
        #expect(TemplateStepGenerator.match("start laundry") == .laundry)
    }

    @Test
    func matchingUsesWordBoundaries() {
        // The bug this guards: "teeth" contains "eat", so a substring match
        // sends someone who typed "teeth" to the eating chain.
        #expect(TemplateStepGenerator.match("brush my teeth") != .eating)
        #expect(TemplateStepGenerator.match("my teeth are gross") == .hygiene)
    }

    @Test
    func matchingIsCaseInsensitive() {
        #expect(TemplateStepGenerator.match("SHOWER") == .shower)
        #expect(TemplateStepGenerator.match("Take My Meds") == .medication)
    }

    /// "up" is a phrasal-verb particle and matches work in every domain.
    ///
    /// Found by running the table against real titles: "clean up the kitchen"
    /// matched `wakingUp` and offered "Put both feet on the floor" for a sink
    /// full of dishes. These are the sentences that caught it.
    @Test
    func upDoesNotSendUnrelatedTasksToWaking() {
        #expect(TemplateStepGenerator.match("clean up the kitchen") != .wakingUp)
        #expect(TemplateStepGenerator.match("pick up my prescription") == .medication)
        #expect(TemplateStepGenerator.match("wash up the plates") == .dishes)
    }

    /// The waking chain is still reachable by the words that actually mean it.
    @Test
    func wakingStillMatchesItsOwnPhrasings() {
        #expect(TemplateStepGenerator.match("wake up") == .wakingUp)
        #expect(TemplateStepGenerator.match("get out of bed") == .wakingUp)
        #expect(TemplateStepGenerator.match("my morning alarm") == .wakingUp)
    }

    @Test
    func unmatchedTitleReturnsNil() {
        #expect(TemplateStepGenerator.match("renew my passport") == nil)
        #expect(TemplateStepGenerator.match("") == nil)
    }
}
