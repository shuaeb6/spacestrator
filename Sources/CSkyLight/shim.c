#include "include/CSkyLight.h"
#include <dlfcn.h>

/*
 * All SkyLight symbols are resolved lazily from the private framework binary.
 * We never link against it directly, so the package builds without referencing
 * any private framework at link time.
 */

static void *skylight_handle(void) {
    static void *handle = NULL;
    static int tried = 0;
    if (!tried) {
        tried = 1;
        handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY | RTLD_GLOBAL);
    }
    return handle;
}

/* CoreDockSendNotification lives in ApplicationServices (also re-exported by
 * Carbon). AppKit already loads ApplicationServices, so RTLD_DEFAULT usually
 * resolves it; we fall back to an explicit dlopen just in case. */
static void *appservices_handle(void) {
    static void *handle = NULL;
    static int tried = 0;
    if (!tried) {
        tried = 1;
        handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
                        RTLD_LAZY | RTLD_GLOBAL);
    }
    return handle;
}

/* ---- function pointer typedefs (private, undocumented signatures) ---- */
typedef int (*SLSMainConnectionID_f)(void);
typedef CFStringRef (*SLSCopyActiveMenuBarDisplayIdentifier_f)(int cid);
typedef CFArrayRef (*SLSCopyManagedDisplaySpaces_f)(int cid);
typedef CFArrayRef (*SLSCopySpacesForWindows_f)(int cid, int selector, CFArrayRef windows);
typedef void (*SLSManagedDisplaySetCurrentSpace_f)(int cid, CFStringRef display, uint64_t space);
typedef uint64_t (*SLSSpaceCreate_f)(int cid, int type, int unknown);
typedef void (*SLSSpaceSetType_f)(int cid, uint64_t space, int type);
typedef void (*SLSShowSpaces_f)(int cid, CFArrayRef spaces);
typedef void (*CoreDockSendNotification_f)(CFStringRef notification, int unknown);

#define BIND(sym, type) ((type)dlsym(skylight_handle(), sym))

int wo_main_connection(void) {
    void *h = skylight_handle();
    if (!h) return 0;
    SLSMainConnectionID_f f = BIND("SLSMainConnectionID", SLSMainConnectionID_f);
    if (!f) return 0;
    return f();
}

CFStringRef wo_active_display_identifier(void) {
    if (!skylight_handle()) return NULL;
    SLSCopyActiveMenuBarDisplayIdentifier_f f =
        BIND("SLSCopyActiveMenuBarDisplayIdentifier", SLSCopyActiveMenuBarDisplayIdentifier_f);
    if (!f) return NULL;
    return f(wo_main_connection());
}

CFArrayRef wo_copy_managed_display_spaces(void) {
    if (!skylight_handle()) return NULL;
    SLSCopyManagedDisplaySpaces_f f =
        BIND("SLSCopyManagedDisplaySpaces", SLSCopyManagedDisplaySpaces_f);
    if (!f) return NULL;
    return f(wo_main_connection());
}

CFArrayRef wo_copy_spaces_for_windows(CFArrayRef window_ids, int selector) {
    if (!skylight_handle() || window_ids == NULL) return NULL;
    SLSCopySpacesForWindows_f f =
        BIND("SLSCopySpacesForWindows", SLSCopySpacesForWindows_f);
    if (!f) return NULL;
    return f(wo_main_connection(), selector, window_ids);
}

void wo_set_current_space(CFStringRef display_identifier, uint64_t space_id) {
    if (!skylight_handle() || display_identifier == NULL) return;
    SLSManagedDisplaySetCurrentSpace_f f =
        BIND("SLSManagedDisplaySetCurrentSpace", SLSManagedDisplaySetCurrentSpace_f);
    if (!f) return;
    f(wo_main_connection(), display_identifier, space_id);
}

uint64_t wo_create_space_on_active_display(void) {
    if (!skylight_handle()) return 0;
    SLSSpaceCreate_f create = BIND("SLSSpaceCreate", SLSSpaceCreate_f);
    if (!create) return 0;
    /* type 0 == user/standard space on most observed versions; the trailing
     * argument is an undocumented flags field that is conventionally 0. */
    uint64_t sid = create(wo_main_connection(), 0, 0);
    if (sid == 0) return 0;

    SLSSpaceSetType_f set_type = BIND("SLSSpaceSetType", SLSSpaceSetType_f);
    if (set_type) set_type(wo_main_connection(), sid, 0);

    SLSShowSpaces_f show = BIND("SLSShowSpaces", SLSShowSpaces_f);
    if (show) {
        CFNumberRef num = CFNumberCreate(NULL, kCFNumberSInt64Type, &sid);
        const void *vals[1] = { num };
        CFArrayRef arr = CFArrayCreate(NULL, vals, 1, &kCFTypeArrayCallBacks);
        show(wo_main_connection(), arr);
        CFRelease(arr);
        CFRelease(num);
    }
    return sid;
}

bool wo_skylight_available(void) {
    if (!skylight_handle()) return false;
    return BIND("SLSMainConnectionID", void *) != NULL
        && BIND("SLSManagedDisplaySetCurrentSpace", void *) != NULL
        && BIND("SLSCopyManagedDisplaySpaces", void *) != NULL;
}

void wo_core_dock_send_notification(CFStringRef notification) {
    if (notification == NULL) return;
    CoreDockSendNotification_f f =
        (CoreDockSendNotification_f)dlsym(RTLD_DEFAULT, "CoreDockSendNotification");
    if (!f) {
        void *h = appservices_handle();
        if (h) f = (CoreDockSendNotification_f)dlsym(h, "CoreDockSendNotification");
    }
    if (f) f(notification, 0);
}
