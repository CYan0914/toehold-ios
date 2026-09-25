import Foundation

// `canImport` below tests whether the framework exists in the SDK; it does not
// bring anything into scope. Without this import the guard passes and every
// name inside it is still an error -- which is exactly how this failed the
// first CI run: "cannot find 'SystemLanguageModel' in scope" at the line the
// `#if` was supposed to be protecting.
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Picks the generator. This is the only place in the app that knows two
/// implementations exist, and the only place that checks device capability.
///
/// The check happens once per request rather than once per launch, because
/// Apple Intelligence can be switched off in Settings between one breakdown and
/// the next. Caching the answer would leave a person with a generator that
/// throws on every call and no way to recover short of reinstalling.
enum StepGeneratorFactory {
    /// Whether the on-device model can be used right now. `false` on any device
    /// that does not support Apple Intelligence, in an unsupported region, or
    /// with the feature turned off.
    static var isAIAvailable: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return AIAvailability.isModelReady()
    }

    /// The generator to use for one request.
    ///
    /// Never returns nil and never fails. A device that cannot run the model
    /// gets the template generator, which is a real path through the product
    /// rather than an error state -- the core loop (type a thing, get small
    /// steps, do them one at a time) works identically either way.
    static func make() -> any StepGenerator {
        if #available(iOS 26.0, *), AIAvailability.isModelReady() {
            return AIStepGenerator()
        }
        return TemplateStepGenerator()
    }
}

/// Isolated so the availability check has one definition and the factory's
/// branches can be tested without constructing a real model.
enum AIAvailability {
    static func isModelReady() -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
            return false
        }
        return false
        #else
        return false
        #endif
    }
}
