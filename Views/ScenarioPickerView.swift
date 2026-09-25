import SwiftUI

/// The row of situation tiles under the text field.
///
/// This is the fastest path through the app and the one most people will use:
/// tapping "Take a shower" is one tap to steps, where typing the same thing is
/// a tap on the field, eight taps on a keyboard, and a tap on the arrow. Both
/// exist because the two kinds of stuck are different -- someone who cannot
/// start knows what they cannot start, and asking them to type it is asking
/// them to do the thing they came here unable to do.
///
/// The tile titles come from `CareScenario.title` and are written as the
/// person's own complaint ("Take a shower"), never as a category ("Hygiene").
/// A category is a word you need to be calm to translate.
struct ScenarioPickerView: View {
    let onPick: (CareScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or pick one")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CareScenario.allCases, id: \.self) { scenario in
                        Button {
                            onPick(scenario)
                        } label: {
                            tile(for: scenario)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            // The strip bleeds past the parent's padding so tiles scroll off the
            // edge rather than stopping short of it, which is what tells a
            // person there is more to the right. Without it the last visible
            // tile sits flush with the margin and the row reads as complete.
            .padding(.horizontal, -20)
        }
    }

    private func tile(for scenario: CareScenario) -> some View {
        VStack(spacing: 8) {
            Image(systemName: scenario.symbolName)
                .font(.title3)
                .frame(height: 22)
            Text(scenario.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                // Two-line titles have to be allowed to grow rather than be
                // truncated, or "Make something to eat" clips to "Make
                // something to..." and the tile stops being readable at a
                // glance, which is the only way it is ever read.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 96, height: 84)
        .padding(6)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
}
