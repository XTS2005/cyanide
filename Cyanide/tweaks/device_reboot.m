//
//  device_reboot.m
//  Cyanide
//
//  See device_reboot.h.
//

#import "device_reboot.h"
#import "remote_objc.h"
#import "../kexploit/kexploit_opa334.h"

// Selectors that have, at various points, existed on SpringBoard or on
// SpringBoard-side singletons for restarting the device. Which ones are real
// varies by iOS version, so every one of these is feature-detected rather than
// assumed. Ordered cheapest/safest first.
static const char *const kDirectRebootSelectors[] = {
    "reboot",
    "_reboot",
    "rebootDevice",
    "_rebootDevice",
    "restartDevice",
    NULL,
};

static uint64_t reboot_springboard_app(void)
{
    uint64_t clsSB = r_class("SpringBoard");
    if (!r_is_objc_ptr(clsSB)) return 0;
    uint64_t sb = r_msg2(clsSB, "sharedApplication", 0, 0, 0, 0);
    return r_is_objc_ptr(sb) ? sb : 0;
}

void device_reboot_probe(void)
{
    uint64_t sb = reboot_springboard_app();
    printf("[REBOOT] probe: SpringBoard app = %#llx\n", sb);
    if (!sb) {
        printf("[REBOOT] probe: no SpringBoard application object\n");
        return;
    }

    for (int i = 0; kDirectRebootSelectors[i]; i++) {
        printf("[REBOOT] probe: -[SpringBoard %s] -> %s\n",
               kDirectRebootSelectors[i],
               r_responds_main(sb, kDirectRebootSelectors[i]) ? "YES" : "no");
    }

    const char *const classes[] = {
        "FBSSystemService", "SBSRelaunchAction", "SBSystemShutdownController", NULL
    };
    for (int i = 0; classes[i]; i++) {
        uint64_t c = r_class(classes[i]);
        printf("[REBOOT] probe: class %s -> %#llx\n", classes[i], c);
    }

    uint64_t fbs = r_class("FBSSystemService");
    if (r_is_objc_ptr(fbs)) {
        uint64_t svc = r_msg2(fbs, "sharedService", 0, 0, 0, 0);
        printf("[REBOOT] probe: FBSSystemService sharedService = %#llx\n", svc);
        if (r_is_objc_ptr(svc)) {
            const char *const sel[] = {
                "shutdownWithOptions:", "rebootWithOptions:", "sendActions:withResult:", NULL
            };
            for (int i = 0; sel[i]; i++) {
                printf("[REBOOT] probe: -[FBSSystemService %s] -> %s\n",
                       sel[i], r_responds_main(svc, sel[i]) ? "YES" : "no");
            }
        }
    }
}

bool device_reboot_now(void)
{
    if (!kexploit_krw_ready()) {
        printf("[REBOOT] no KRW session; cannot reach SpringBoard\n");
        log_user("[REBOOT] Needs a live kernel session. Run the chain first.\n");
        return false;
    }

    uint64_t sb = reboot_springboard_app();
    if (!sb) {
        printf("[REBOOT] could not get the SpringBoard application object\n");
        return false;
    }

    // 1. A direct selector on SpringBoard, if this iOS version has one.
    for (int i = 0; kDirectRebootSelectors[i]; i++) {
        if (!r_responds_main(sb, kDirectRebootSelectors[i])) continue;
        printf("[REBOOT] dispatching -[SpringBoard %s]\n", kDirectRebootSelectors[i]);
        log_user("[REBOOT] Rebooting via SpringBoard (%s)...\n", kDirectRebootSelectors[i]);
        r_msg2_main_async(sb, kDirectRebootSelectors[i], 0, 0, 0, 0);
        return true;
    }

    // 2. FBSSystemService. Its shutdown entry point takes an options mask;
    //    reboot rather than power-off is the low bit on the versions where this
    //    exists. Only used if the selector is actually present.
    uint64_t fbs = r_class("FBSSystemService");
    if (r_is_objc_ptr(fbs)) {
        uint64_t svc = r_msg2(fbs, "sharedService", 0, 0, 0, 0);
        if (r_is_objc_ptr(svc)) {
            if (r_responds_main(svc, "rebootWithOptions:")) {
                printf("[REBOOT] dispatching -[FBSSystemService rebootWithOptions:0]\n");
                log_user("[REBOOT] Rebooting via FBSSystemService...\n");
                r_msg2_main_async(svc, "rebootWithOptions:", 0, 0, 0, 0);
                return true;
            }
            if (r_responds_main(svc, "shutdownWithOptions:")) {
                printf("[REBOOT] dispatching -[FBSSystemService shutdownWithOptions:1]\n");
                log_user("[REBOOT] Rebooting via FBSSystemService...\n");
                r_msg2_main_async(svc, "shutdownWithOptions:", 1, 0, 0, 0);
                return true;
            }
        }
    }

    printf("[REBOOT] no usable reboot entry point found\n");
    log_user("[REBOOT] Could not find a reboot entry point on this iOS version. "
             "The log above lists what SpringBoard exposes — reboot manually for now.\n");
    device_reboot_probe();
    return false;
}
