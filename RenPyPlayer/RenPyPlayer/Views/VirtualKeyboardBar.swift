import SwiftUI

/// A minimal, always-available text entry bar for Ren'Py games that pop up
/// `renpy.input()` prompts (name entry, etc). Rather than hiding and
/// re-summoning the system keyboard over an SDL-rendered surface — which is
/// unreliable — this presents its own text field and streams each
/// character to the engine as it's typed.
struct VirtualKeyboardBar: View {
    @Binding var text: String
    let onCharacter: (UInt32) -> Void

    var body: some View {
        HStack {
            TextField("Type here…", text: $text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { oldValue, newValue in
                    guard newValue.count > oldValue.count, let added = newValue.last else { return }
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
