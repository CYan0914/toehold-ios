import Foundation
import SwiftData

/// One step of a task. Small on purpose -- the whole product bet is that a step
/// a person will actually do beats a step that describes the work accurately.
///
/// Same CloudKit constraints as `TaskItem`: defaults on everything
/// non-optional, the back-reference is optional.
@Model
final class StepItem {
    var id: UUID = UUID()

    var text: String = ""

    /// Position in the task. Explicit rather than inferred from insertion
    /// order, because CloudKit does not preserve array order across devices.
    var order: Int = 0

    var done: Bool = false
    var doneAt: Date?

    /// The inverse of `TaskItem.steps`. Optional because a partial record can
    /// arrive before its parent; SwiftData fills it in when the parent lands.
    var task: TaskItem?

    init(text: String, order: Int) {
        self.id = UUID()
        self.text = text
        self.order = order
        self.done = false
    }
}
