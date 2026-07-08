#ifndef CSKYLIGHT_H
#define CSKYLIGHT_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdbool.h>

/*
 * Thin C wrappers over Apple's *private* SkyLight framework.
 *
 * These functions are undocumented and their availability/signature can change
 * between macOS releases. Every wrapper below is bound lazily at runtime via
 * dlopen()/dlsym(); if a symbol is missing the wrapper degrades gracefully
 * (returns NULL / 0 / does nothing) instead of crashing or failing to link.
 *
 * Because of that fragility, the Swift SpaceManager prefers the yabai backend
 * when yabai is installed and only falls back to these calls otherwise.
 *
 * The READ path (enumerate spaces, map windows -> spaces) uses symbols that have
 * been stable and widely used for years. The WRITE path (create a space) is the
 * version-sensitive part and is intentionally best-effort.
 */

/* Returns the main SkyLight connection id for this process, or 0 if unavailable. */
int wo_main_connection(void);

/* Identifier string of the display that currently owns the menu bar (caller must CFRelease). */
CFStringRef wo_active_display_identifier(void);

/* Managed-display space topology (caller must CFRelease). Mirrors SLSCopyManagedDisplaySpaces. */
CFArrayRef wo_copy_managed_display_spaces(void);

/* For an array of CGWindowID (as CFNumber), returns the spaces they live on (caller must CFRelease). */
CFArrayRef wo_copy_spaces_for_windows(CFArrayRef window_ids, int selector);

/* Switch the given display to the managed space id. No-op if the symbol is unavailable. */
void wo_set_current_space(CFStringRef display_identifier, uint64_t space_id);

/* Best-effort: create a new managed space on the active display and return its id (0 on failure). */
uint64_t wo_create_space_on_active_display(void);

/* True if the private SkyLight switch/enumerate symbols resolved successfully. */
bool wo_skylight_available(void);

/*
 * Post a CoreDock notification (e.g. CFSTR("com.apple.expose.awake") to toggle
 * Mission Control). This is how the reliable, version-independent space control
 * path drives Mission Control — the same mechanism Hammerspoon's hs.spaces uses.
 * Resolved from ApplicationServices at runtime; no-op if the symbol is missing.
 */
void wo_core_dock_send_notification(CFStringRef notification);

#endif /* CSKYLIGHT_H */
