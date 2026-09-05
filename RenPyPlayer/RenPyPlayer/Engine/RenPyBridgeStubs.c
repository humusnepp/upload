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
#include <fcntl.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>

// Weak symbol declarations so the bridge safely invokes the real Ren'Py
// engine when librenpython.a / libSDL2.a are linked, or cleanly operates in stub mode.
extern int launcher_main(int argc, char **argv) __attribute__((weak));
extern int renpython_main(int argc, char **argv) __attribute__((weak));
extern int SDL_PushEvent(void *event) __attribute__((weak));

static bool s_running = false;
static float s_scale = 1.0f;
static char s_log_path[1024] = {0};

const char *renpy_get_log_path(void) {
    return s_log_path;
}

static void setup_stdio_redirection(const char *savesPath) {
    if (savesPath && strlen(savesPath) > 0) {
        snprintf(s_log_path, sizeof(s_log_path), "%s/engine_output.log", savesPath);
    } else {
        snprintf(s_log_path, sizeof(s_log_path), "/tmp/engine_output.log");
    }

    fflush(stdout);
    fflush(stderr);

    int fd = open(s_log_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        close(fd);
    }

    freopen(s_log_path, "a", stdout);
    freopen(s_log_path, "a", stderr);

    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    fprintf(stdout, "[RenPyBridge] Stdio redirected to: %s\n", s_log_path);
    fflush(stdout);
}

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

    // Set up stdout & stderr capture to engine_output.log
    setup_stdio_redirection(savesPath);

    fprintf(stdout, "[RenPyBridge] SUCCESS: Game verified at: %s\n", gamePath);
    fprintf(stdout, "[RenPyBridge] Saves path: %s\n", savesPath);
    s_running = true;

    // Check if the native Ren'Py runtime (librenpython) is linked
    if (launcher_main != NULL || renpython_main != NULL) {
        fprintf(stdout, "[RenPyBridge] Native Ren'Py runtime detected! Initializing runtime paths...\n");

        CFBundleRef mainBundle = CFBundleGetMainBundle();

        // 1. Full executable path for argv[0] so librenpython's _take_argv0 finds the bundle
        char exePath[1024] = {0};
        CFURLRef exeURL = CFBundleCopyExecutableURL(mainBundle);
        if (exeURL) {
            CFURLGetFileSystemRepresentation(exeURL, true, (UInt8 *)exePath, sizeof(exePath));
            CFRelease(exeURL);
        }

        // 2. Resources / Bundle path
        CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
        char resourcePath[1024] = {0};
        if (resourcesURL) {
            CFURLGetFileSystemRepresentation(resourcesURL, true, (UInt8 *)resourcePath, sizeof(resourcePath));
            CFRelease(resourcesURL);
        }

        if (strlen(exePath) == 0) {
            snprintf(exePath, sizeof(exePath), "%s/RenPyPlayer", resourcePath);
        }

        char baseDir[1024];
        snprintf(baseDir, sizeof(baseDir), "%s/base", resourcePath);

        char libDir[1024];
        snprintf(libDir, sizeof(libDir), "%s/base/lib/python3.9", resourcePath);

        char rootLibDir[1024];
        snprintf(rootLibDir, sizeof(rootLibDir), "%s/lib/python3.9", resourcePath);

        char zipDir[1024];
        snprintf(zipDir, sizeof(zipDir), "%s/base/lib/python39.zip", resourcePath);

        fprintf(stdout, "[RenPyBridge] exePath: %s\n", exePath);
        fprintf(stdout, "[RenPyBridge] baseDir: %s\n", baseDir);
        fprintf(stdout, "[RenPyBridge] libDir: %s\n", libDir);
        fflush(stdout);

        // Configure environment variables for Ren'Py
        setenv("RENPY_PLATFORM", "ios-arm64", 1);
        if (strlen(resourcePath) > 0) {
            setenv("RENPY_BASE", baseDir, 1);
            setenv("PYTHONHOME", baseDir, 1);
            char pythonPath[4096];
            snprintf(pythonPath, sizeof(pythonPath), "%s:%s:%s:%s:%s", baseDir, libDir, rootLibDir, zipDir, gamePath);
            setenv("PYTHONPATH", pythonPath, 1);
        }

        // Arguments for Ren'Py entry point
        // argv[0] = exePath (must have '/' so _take_argv0 locates the bundle)
        // argv[1] = gamePath (basedir)
        // argv[2] = "--savedir"
        // argv[3] = savesPath
        char *argv[6];
        argv[0] = exePath;
        argv[1] = (char *)gamePath;
        argv[2] = "--savedir";
        argv[3] = (char *)savesPath;
        argv[4] = NULL;
        int argc = 4;

        int exitCode = 0;
        if (launcher_main != NULL) {
            fprintf(stdout, "[RenPyBridge] Calling official launcher_main(argc=%d)...\n", argc);
            fflush(stdout);
            exitCode = launcher_main(argc, argv);
            fprintf(stdout, "[RenPyBridge] launcher_main finished with code: %d\n", exitCode);
        } else {
            fprintf(stdout, "[RenPyBridge] Calling renpython_main with explicit main.py...\n");
            fflush(stdout);
            char mainPyPath[1024];
            snprintf(mainPyPath, sizeof(mainPyPath), "%s/main.py", baseDir);
            char *py_argv[7];
            py_argv[0] = exePath;
            py_argv[1] = mainPyPath;
            py_argv[2] = (char *)gamePath;
            py_argv[3] = "--savedir";
            py_argv[4] = (char *)savesPath;
            py_argv[5] = NULL;
            exitCode = renpython_main(5, py_argv);
            fprintf(stdout, "[RenPyBridge] renpython_main finished with code: %d\n", exitCode);
        }

        fflush(stdout);
        fflush(stderr);
        s_running = false;
        return exitCode;
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
    fprintf(stdout, "[RenPyBridge] Stop requested.\n");
    fflush(stdout);

    if (SDL_PushEvent != NULL) {
        // Send SDL_QUIT event to gracefully exit Ren'Py main loop
        struct {
            uint32_t type;
            uint32_t timestamp;
            uint8_t padding[48];
        } quit_event;
        memset(&quit_event, 0, sizeof(quit_event));
        quit_event.type = 0x100; // SDL_QUIT
        SDL_PushEvent(&quit_event);
        fprintf(stdout, "[RenPyBridge] Pushed SDL_QUIT event.\n");
        fflush(stdout);
    }
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
    return (launcher_main != NULL || renpython_main != NULL);
}

