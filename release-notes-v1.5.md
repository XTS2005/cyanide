# Cyanide 1.5

Stability and performance release, headlined by a much more reliable exploit path
on A18/M4 devices.

## New

- **A18/M4 devices now use the `pe_v1` exploit path.** Acquire time drops from
  9–12 s to under 4 s, and fresh runs are far less likely to end in a kernel
  panic. `pe_v2` is still selectable under **Settings → Launch → A18 exploit
  path** if you need it.
- **Settings → Launch → Tweak apply speed** — Compatible (default) / Fast /
  Fastest. Higher settings cut the delay paid between remote calls, so tweaks
  apply noticeably quicker.
- **Idle parking.** Cyanide now parks its kernel read/write state after a second
  of inactivity, so an abrupt kill — jetsam, force-quit, crash — is far less
  likely to leave the kernel in a dangerous state.

## Fixed

- **Kernel panics hours or days after using Cyanide.** Closing the app without
  any live tweaks active skipped cleanup entirely, leaving the kernel pointing at
  memory that would later be freed. This was the cause of the delayed random
  panics.
- **M-series iPads: tweaks now apply.** Setting up the SpringBoard session had
  never worked on these devices — the exploit succeeded but every tweak failed.
- **Chain logs survive a kernel panic** instead of being left empty, so a
  panicking run can actually be diagnosed.
- **Crash when A18 staging could not allocate memory.** It now reports the
  problem, and falls back to a smaller size rather than failing the run outright.
- **Kernel writes near a page boundary** could fault.
- Several `pe_v2` issues: a large per-run resource leak, silently ignored
  allocation failures, and the app quitting outright on recoverable errors.

## Improved

- Read-only operations no longer pay the inter-call delay, which speeds up every
  tweak that walks Home Screen pages or windows.
- Diagnostics that were previously impossible to enable on a sideloaded build now
  follow the app's own verbose logging.

## Notes

Tested on iPhone 16 Pro Max (A18 Pro, iOS 18.5). Fresh A18 runs can still
occasionally panic — that is inherent to the technique and `pe_v1` reduces it
rather than removing it. Once a run succeeds, later launches skip the exploit
entirely.
