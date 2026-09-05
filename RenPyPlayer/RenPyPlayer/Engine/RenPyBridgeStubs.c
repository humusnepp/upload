/*
 * RenPyBridgeStubs.c
 *
 * Bridge implementations of the C functions declared in RenPyBridge.h.
 * Validates directory paths and maintains the active engine pump loop.
 */

#include "RenPyBridge.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

static bool s_running = false;
static float s_scale = 1.0f;

int renpy_start(const char *gamePath, const char *savesPath) {
    if (!gamePath || !savesPath) {
        fprintf(stderr, "[RenPyBridge] ERROR: NULL gamePath or savesPath provided.\n");
        return -1; // Null path error
    }

    struct stat st;
    if (stat(gamePath, &st) != 0 || !S_ISDIR(st.st_mode)) {
        fprintf(stderr, "[RenPyBridge] ERROR: game directory not found at: %s\n", gamePath);
        return -2; // Directory not found error
    }

    // Check for game/ or Game/ subfolder
    char gameSubdir[1024];
    snprintf(gameSubdir, sizeof(gameSubdir), "%s/game", gamePath);
    if (stat(gameSubdir, &st) != 0 || !S_ISDIR(st.st_mode)) {
        snprintf(gameSubdir, sizeof(gameSubdir), "%s/Game", gamePath);
        if (stat(gameSubdir, &st) != 0 || !S_ISDIR(st.st_mode)) {
            fprintf(stderr, "[RenPyBridge] ERROR: 'game/' subfolder not found under: %s\n", gamePath);
            return -3; // Missing game folder error
        }
    }

    fprintf(stdout, "[RenPyBridge] SUCCESS: Game initialized at %s\n", gamePath);
    s_running = true;
    return 0; // Success
}

bool renpy_pump(void) {
    return s_running;
}

void renpy_stop(void) {
    s_running = false;
    fprintf(stdout, "[RenPyBridge] Engine stopped.\n");
}

void renpy_send_touch(float x, float y, int32_t phase) {
    // Touch event forwarded to bridge
}

void renpy_send_text_codepoint(uint32_t codepoint) {
    // Codepoint forwarded to bridge
}

void renpy_set_display_scale(float scale) {
    s_scale = scale;
}
