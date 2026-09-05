//
//  RenPyBridge.h
//
//  Declares the C entry points this app expects from the Ren'Py iOS SDK.
//  These are NOT implemented in this project — they must be provided by
//  linking Ren'Py's official iOS build (from the "rapt"/iOS export in the
//  Ren'Py SDK at renpy.org), which bundles Python 3, SDL2, and the Ren'Py
//  engine itself as a static library / xcframework for arm64.
//
//  See README.md, section "Wiring up the real Ren'Py SDK", for exactly
//  what needs linking and where these symbols come from.
//

#ifndef RenPyBridge_h
#define RenPyBridge_h

#include <stdbool.h>
#include <stdint.h>

/// Starts the embedded Ren'Py/Python runtime pointed at `gamePath` (an
/// absolute path to a directory containing a `game/` subfolder) and tells
/// it to write saves under `savesPath`. Returns 0 on success.
int renpy_start(const char *gamePath, const char *savesPath);

/// Pumps the Ren'Py/SDL event loop once. Returns false once the game has
/// quit (the player chose Quit, or the script called renpy.quit()).
bool renpy_pump(void);

/// Cleanly shuts down the interpreter and releases SDL resources. Safe to
/// call even if renpy_start never succeeded.
void renpy_stop(void);

/// Forwards a touch/mouse event into SDL's event queue. `phase` matches
/// TouchPhaseForBridge's rawValue (0=began, 1=moved, 2=ended, 3=cancelled).
/// Coordinates are in the view's point space; the implementation is
/// responsible for scaling into the game's logical resolution.
void renpy_send_touch(float x, float y, int32_t phase);

/// Forwards a single Unicode codepoint of text input (from the on-screen
/// virtual keyboard bar) as an SDL_TEXTINPUT-equivalent event.
void renpy_send_text_codepoint(uint32_t codepoint);

/// Adjusts the renderer's output scale factor. Called on launch and
/// whenever the user changes it in Settings.
void renpy_set_display_scale(float scale);

/// Returns true if the native Ren'Py binary runtime is linked and active.
bool renpy_is_native(void);

/// Returns the path to the engine stdout/stderr log file.
const char *renpy_get_log_path(void);

#endif /* RenPyBridge_h */
