import SwiftUI

/// A minimal, always-available text entry bar for Ren'Py games that pop up
/// `renpy.input()` prompts (name entry, etc). Rather than hiding and
/// re-summoning the system keyboard over an SDL-rendered surface — which is
/// unreliable — this presents its own text field and streams each
/// character to the engine as it's typed.
struct VirtualKeyboardBar: View {
    @Binding var text: String
    let onCharacter: (UInt32) -> Void

    /// Tracks the previous value so we can detect which character was added.
    /// Needed because the iOS 16-compatible onChange only receives the new value.
    @State private var previousText: String = ""

    var body: some View {
        HStack {
            TextField("Type here…", text: $text)
                .textFieldStyle(.roundedBorder)
                // onChange(of:perform:) is available from iOS 14+.
                // The iOS 17+ two-parameter form (oldValue, newValue) must
                // not be used here to keep the deployment target at iOS 16.
                .onChange(of: text) { newValue in
                    let old = previousText
                    previousText = newValue
                    guard newValue.count > old.count, let added = newValue.last else { return }
                    for scalar in String(added).unicodeScalars {
                        onCharacter(scalar.value)
                    }
                }
            Button("Enter") {
                onCharacter(0x0D) // carriage return
                text = ""
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
