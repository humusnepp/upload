/*
 * RenPyBridgeStubs.c
 *
 * Bridge implementation connecting the SwiftUI player shell to the
 * embedded Ren'Py / Python runtime.
 */

#include "RenPyBridge.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <CoreFoundation/CoreFoundation.h>

// Weak symbol declarations so the bridge safely invokes the real Ren'Py
// engine when librenpython.a is linked, or cleanly operates in stub mode.
extern int launcher_main(int argc, char **argv) __attribute__((weak));
extern int renpython_main(int argc, char **argv) __attribute__((weak));

static bool s_running = false;
static float s_scale = 1.0f;

int renpy_start(const char *gamePath, const char *savesPath) {
    if (!gamePath || !savesPath) {
        fprintf(stderr, "[RenPyBridge] ERROR: NULL gamePath or savesPath provided.\n");
        return -1;
    }

    struct stat st;
    if (stat(gamePath, &st) != 0 || !S_ISDIR(st.st_mode)) {
        fprintf(stderr, "[RenPyBridge] ERROR: game directory not found at: %s\n", gamePath);
        return -2;
    }

    // Check for game/ or Game/ subfolder
    char gameSubdir[1024];
    snprintf(gameSubdir, sizeof(gameSubdir), "%s/game", gamePath);
    if (stat(gameSubdir, &st) != 0 || !S_ISDIR(st.st_mode)) {
        snprintf(gameSubdir, sizeof(gameSubdir), "%s/Game", gamePath);
        if (stat(gameSubdir, &st) != 0 || !S_ISDIR(st.st_mode)) {
            fprintf(stderr, "[RenPyBridge] ERROR: 'game/' subfolder not found under: %s\n", gamePath);
            return -3;
        }
    }

    fprintf(stdout, "[RenPyBridge] SUCCESS: Game verified at: %s\n", gamePath);
    s_running = true;

    // Check if the native Ren'Py runtime (librenpython) is linked
    if (renpython_main != NULL || launcher_main != NULL) {
        fprintf(stdout, "[RenPyBridge] Native Ren'Py runtime detected! Launching engine...\n");

        // Locate the base directory inside the app bundle
        CFBundleRef mainBundle = CFBundleGetMainBundle();
        CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
        char resourcePath[1024] = {0};
        if (resourcesURL) {
            CFURLGetFileSystemRepresentation(resourcesURL, true, (UInt8 *)resourcePath, sizeof(resourcePath));
            CFRelease(resourcesURL);
        }

        char baseDir[1024];
        snprintf(baseDir, sizeof(baseDir), "%s/base", resourcePath);

        char libDir[1024];
        snprintf(libDir, sizeof(libDir), "%s/base/lib/python3.9", resourcePath);

        char rootLibDir[1024];
        snprintf(rootLibDir, sizeof(rootLibDir), "%s/lib/python3.9", resourcePath);

        char zipDir[1024];
        snprintf(zipDir, sizeof(zipDir), "%s/base/lib/python39.zip", resourcePath);

        // Configure environment variables for Ren'Py
        setenv("RENPY_PLATFORM", "ios-arm64", 1);
        if (strlen(resourcePath) > 0) {
            setenv("RENPY_BASE", baseDir, 1);
            setenv("PYTHONHOME", baseDir, 1);
            char pythonPath[4096];
            snprintf(pythonPath, sizeof(pythonPath), "%s:%s:%s:%s:%s", baseDir, libDir, rootLibDir, zipDir, gamePath);
            setenv("PYTHONPATH", pythonPath, 1);
        }

        // Construct arguments for Ren'Py entry point
        char *argv[6];
        argv[0] = "RenPyPlayer";
        argv[1] = (char *)gamePath;
        argv[2] = "--savedir";
        argv[3] = (char *)savesPath;
        argv[4] = NULL;
        int argc = 4;

        if (renpython_main) {
            return renpython_main(argc, argv);
        } else {
            return launcher_main(argc, argv);
        }
    } else {
        fprintf(stdout, "[RenPyBridge] Running in stub mode (native libraries not linked).\n");
        return 0;
    }
}

bool renpy_pump(void) {
    return s_running;
}

void renpy_stop(void) {
    s_running = false;
    fprintf(stdout, "[RenPyBridge] Engine stopped.\n");
}

void renpy_send_touch(float x, float y, int32_t phase) {
    // Touch coordinates can be forwarded to SDL2 event queue
}

void renpy_send_text_codepoint(uint32_t codepoint) {
    // Virtual keyboard text forwarded to SDL2
}

void renpy_set_display_scale(float scale) {
    s_scale = scale;
}

bool renpy_is_native(void) {
    return (renpython_main != NULL || launcher_main != NULL);
}
