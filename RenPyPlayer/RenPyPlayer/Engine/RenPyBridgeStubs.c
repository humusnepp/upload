/*
 * RenPyBridgeStubs.c
 *
 * Stub implementations of the C functions declared in RenPyBridge.h.
 * These allow the project to build and link without the real Ren'Py iOS SDK.
 *
 * To wire in the actual runtime: replace this file with (or link against)
 * the real Ren'Py iOS SDK libraries — see README.md for details.
 */

#include "RenPyBridge.h"
#include <stdbool.h>
#include <stdint.h>

int renpy_start(const char *gamePath, const char *savesPath) {
    // Stub: real implementation comes from the Ren'Py iOS SDK.
    return -1;
}

bool renpy_pump(void) {
    return false;
}

void renpy_stop(void) {
    // Stub
}

void renpy_send_touch(float x, float y, int32_t phase) {
    // Stub
}

void renpy_send_text_codepoint(uint32_t codepoint) {
    // Stub
}

void renpy_set_display_scale(float scale) {
    // Stub
}
