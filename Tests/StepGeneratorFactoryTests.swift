import Testing
@testable import Toehold

/// The factory is the branch that decides whether a person gets the AI
/// breakdown or the template one. Both are real paths through the product, so
/// the assertions here are about which branch is chosen, not about which is
/// better.
struct StepGeneratorFactoryTests {
    @Test
    func sourceMatchesTheGeneratorThatWasBuilt() {
        let generator = StepGeneratorFactory.make()
        // The source is stamped onto every created task, so a mismatch here
        // means the history mislabels where steps came from. The factory's
        // contract is that these two agree; a generator claiming a source it is
        // not is the failure this catches.
        let expected: StepSource = generator is TemplateStepGenerator ? .template : .ai
        #expect(generator.source == expected)
    }

    @Test
    func everyGeneratorProducesStepsOnThisDevice() async throws {
        // The real "never nil, never useless" check: whatever device this test
        // runs on, the generator the factory hands back has to answer.
        //
        // `modelUnavailable` is the one outcome tolerated here, and it has to be
        // spelled out rather than wrapped in a bare `try?`. It means the model
        // cannot run at all -- no Apple Intelligence on this machine, or the
        // weights are not downloaded (which is every CI simulator). In that
        // state the app has already routed the person to the template chain at
        // the call site above the generator, so a throw here is the correct
        // answer rather than a failure. Anything else -- an empty list, a
        // generation error -- is a real defect and still fails the test.
        let generator = StepGeneratorFactory.make()
        do {
            let steps = try await generator.generateSteps(for: "brush my teeth", category: .hygiene)
            #expect(!steps.isEmpty)
        } catch StepGeneratorError.modelUnavailable {
            // Expected on any device without a usable model.
        }
    }

    @Test
    func availabilityIsConsistentWithWhatTheFactoryBuilds() {
        // These two must agree. `isAIAvailable` drives the UI hint and
        // `make()` drives behaviour; if they diverge, the app either promises
        // AI it will not deliver or hides it while using it.
        let generator = StepGeneratorFactory.make()
        let builtAI = !(generator is TemplateStepGenerator)
        #expect(StepGeneratorFactory.isAIAvailable == builtAI)
    }

    @Test
    func templateGeneratorNeverThrows() async throws {
        // The fallback path has to be total. If this can throw, a device
        // without Apple Intelligence has a failure mode the AI path does not.
        let generator = TemplateStepGenerator()
        let steps = try await generator.generateSteps(for: "anything at all", category: nil)
        #expect(!steps.isEmpty)
    }
}
