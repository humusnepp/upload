# RenPyPlayer (iOS)

A SwiftUI app that imports Ren'Py visual-novel projects as `.zip` files and
plays them on-device. This repo contains the complete native app shell —
library, import flow, save-path management, settings, and the SDL/touch
integration layer. It does **not** contain a working Ren'Py runtime, because
that has to come from Ren'Py's own iOS SDK, which is a macOS/Xcode build
artifact I can't produce or download in the environment I write code in.
Below is exactly what's finished, what's stubbed, and what you need to do to
make it actually run a game.

## What's implemented and working as-is

- `Models/Game.swift`, `Models/GameLibrary.swift` — persisted game list
  (JSON index in Documents), thumbnail discovery from
  `game/gui/window_icon.png`.
- `FileManagement/GameImporter.swift` — unzips a `.zip` (via ZIPFoundation),
  validates it actually contains a `game/` folder, flattens nested archive
  layouts, and moves it into the app's sandbox.
- `Views/ImportGameView.swift` — import from Files (local, iCloud Drive, or
  any SMB/network share you've added under Files > Browse > Connect to
  Server — `.fileImporter` surfaces all of those automatically) or from a
  pasted URL via `URLSession.download`.
- `Views/LibraryView.swift` — grid of imported games with thumbnails,
  swipe-to-delete via context menu.
- `Views/GamePlayerView.swift`, `Views/VirtualKeyboardBar.swift` —
  full-screen player chrome, back button, virtual keyboard toggle for
  `renpy.input()` prompts.
- `Settings/AppSettings.swift`, `Views/SettingsView.swift` — screen scale,
  text speed, skip mode, persisted via `UserDefaults`.
- `Engine/RenPyEngineBridge.swift`, `Engine/SDLGameView.swift` — the Swift
  side of the engine lifecycle and touch forwarding, written against the C
  API declared in `RenPyBridge.h`.

## What's stubbed: the actual Ren'Py runtime

`Engine/RenPyBridge.h` declares six C functions —
`renpy_start`, `renpy_pump`, `renpy_stop`, `renpy_send_touch`,
`renpy_send_text_codepoint`, `renpy_set_display_scale` — and nothing in this
project implements them. They're the seam where Ren'Py's real iOS SDK plugs
in. Nothing above that seam (SwiftUI, import flow, settings) needs to change
once it's linked.

### Wiring up the real Ren'Py SDK

1. On a Mac, download the Ren'Py SDK from renpy.org and use its iOS export
   feature (`Launch Project > iOS`), which generates an Xcode project
   (historically under a folder like `renios`) containing Python 3, SDL2,
   and Ren'Py itself pre-built for arm64, plus the glue code that starts the
   interpreter and drives SDL's UIKit view.
2. That generated project is normally *the whole app* — Ren'Py owns
   `main()`. To embed it inside this SwiftUI app instead, you'll pull its
   static libraries / xcframeworks (Python, SDL2, `librenpython`, the
   `game` loader) into this Xcode project as linked frameworks, and reuse
   its Objective-C launch code as the implementation of `renpy_start` etc.,
   rather than letting it run its own `main()`.
3. Add this project's `Engine/RenPyBridge.h` as the bridging header (or
   merge its declarations into whatever bridging header Xcode generates for
   this target) so Swift can see the C symbols.
4. `SDLGameView.swift` assumes SDL2's iOS UIKit view class attaches its
   Metal/GL layer to the `TouchForwardingView` that's on screen when
   `renpy_start` runs — match that to whichever entry point the SDK's
   `renios` project actually exposes (SDL2's iOS template usually creates
   the view itself; you'll adapt `renpy_start` to attach to the view passed
   in rather than creating its own).
5. Resolve the coordinate-scaling `NOTE` in `SDLGameView.swift` — Ren'Py
   games run at a fixed logical resolution declared in `options.rpy`, and
   touch points need scaling from view space into that space.

None of this is guesswork about whether it's possible — Ren'Py has shipped
official iOS support for years — it's just work that requires Xcode, a Mac,
and the actual SDK download, none of which are available where I generated
this code.

## Before you ship this

Apple's App Store guideline 2.5.2 restricts apps whose primary purpose is
downloading and executing third-party interpreted code that wasn't part of
the reviewed binary. An app that imports arbitrary Ren'Py `.zip` files (each
containing arbitrary Python bytecode) is very much in that territory, and is
likely to be rejected on the App Store even though it's fine technically and
legally. This isn't a reason not to build it — it's a normal, common pattern
for personal use, TestFlight with a fixed set of testers, or enterprise/ad
hoc distribution outside the App Store. If App Store distribution matters to
you, it's worth reading Apple's current guideline text before investing
further, since enforcement specifics shift over time.

## Dependencies to add in Xcode

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) — Swift
  Package Manager, used by `GameImporter.swift` for zip extraction.
- SDL2 + the Ren'Py iOS SDK's compiled libraries, per the section above.

## Suggested Info.plist / capabilities

- `UIFileSharingEnabled` = YES and `LSSupportsOpeningDocumentsInPlace` = YES
  if you want games to be importable by AirDropping/opening a `.zip`
  directly onto the app icon in addition to the in-app import flow.
- `UISupportedInterfaceOrientations` — most Ren'Py games are portrait or a
  single fixed orientation; lock this to match the games you plan to
  support, since Ren'Py doesn't rotate its own render surface dynamically.
