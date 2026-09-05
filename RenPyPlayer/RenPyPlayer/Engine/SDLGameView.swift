import SwiftUI
import UIKit

/// Wraps the UIKit view that SDL2 renders into. SDL2's iOS support code
/// (from SDL2's Xcode project template, bundled alongside the Ren'Py iOS
/// SDK) provides a UIView subclass whose CAMetalLayer/CAEAGLLayer backs the
/// game's rendering — `renpy_start` attaches to whatever view is on screen
/// when it's called, which is this one. See README.md for exact wiring.
struct SDLGameView: UIViewRepresentable {
    @ObservedObject var engine: RenPyEngineBridge

    func makeUIView(context: Context) -> TouchForwardingView {
        let view = TouchForwardingView()
        view.engine = engine
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: TouchForwardingView, context: Context) {
        // No-op: once renpy_start() has attached its renderer to this
        // view's layer, SDL owns drawing into it directly.
    }
}

/// Hosts SDL's rendering layer and forwards raw touches to the engine
/// bridge so Ren'Py sees them as mouse/finger events.
final class TouchForwardingView: UIView {
    weak var engine: RenPyEngineBridge?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: .began)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: .moved)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: .ended)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: .cancelled)
    }

    private func forward(_ touches: Set<UITouch>, phase: TouchPhaseForBridge) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        // NOTE: Ren'Py/SDL expects coordinates in the game's logical
        // resolution space (e.g. 1920x1080), not this view's point space.
        // A real integration reads the game's configured resolution from
        // its options.rpy / renpy_start's return metadata and scales
        // `point` accordingly before sending it on.
        Task { @MainActor in
            engine?.sendTouch(x: Float(point.x), y: Float(point.y), phase: phase)
        }
    }
}
