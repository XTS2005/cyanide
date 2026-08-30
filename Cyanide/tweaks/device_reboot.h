//
//  device_reboot.h
//  Cyanide
//
//  Rebooting the device from inside SpringBoard.
//
//  Cyanide never becomes root -- ucred lives in the read-only allocator behind
//  proc_ro, which is exactly what SPTM protects -- so reboot(2) is not
//  available to us. SpringBoard, however, already holds the entitlements for
//  device restart, and we can send it arbitrary ObjC messages over RemoteCall.
//  So we ask SpringBoard to do it, and the reboot goes through the OS's own
//  shutdown path rather than an abrupt syscall.
//
//  Requires a live SpringBoard RemoteCall session, which in turn requires KRW.
//  KRW survives closing the app (the sockets are refcount-leaked and their
//  fileports are parked in launchd), so this works in any session where the
//  chain has run or been recovered -- not only immediately after a fresh run.
//

#ifndef device_reboot_h
#define device_reboot_h

#import <stdbool.h>

// Logs every reboot-capable selector/class SpringBoard actually exposes.
// The private API for this varies across iOS versions, so the first run is a
// discovery run: whatever this prints is the ground truth for this device.
void device_reboot_probe(void);

// Name of the user-created Shortcut used as the no-KRW fallback.
#define CY_REBOOT_SHORTCUT_NAME "Cyanide Reboot"

// True when a SpringBoard-driven reboot is currently possible (i.e. KRW is up).
bool device_reboot_available(void);

// Attempts a reboot via SpringBoard. Returns true only if a reboot action was
// successfully dispatched; false means nothing suitable was found, and the log
// will say what was probed.
bool device_reboot_now(void);

#endif /* device_reboot_h */
