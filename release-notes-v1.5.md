# Cyanide 1.5

Stability and performance release. The headline change is that A18/M4 devices now
use a different, far more reliable exploit path.

## A18/M4: switched to the pe_v1 exploit path

`pe_v1` has always contained a complete A18 path — one 3 GB shaping mapping and a
much smaller search window — but `isA18Device` was never set to true and A18
devices were routed to `pe_v2` instead. That dead path exists, unused, in
DarkSword, darksword-kexploit-fun, Lara and upstream Cyanide alike.

It is now the default on A18/M4. In practice:

| | pe_v2 | pe_v1 A18 path |
| --- | --- | --- |
| IOSurfaces requested | 131,072 | 1 |
| Per-process ceiling | 16,384 (so ~87% always failed, silently) | not approached |
| OOB reads per pass | ~2,047 per mapping | 240 |
| Observed acquire time | 9–12 s | 0.7–3.4 s |

Every OOB read is a chance to fault on an unmapped physical page, so the read
count governs the panic rate directly. Measured across five successful runs,
`pe_v1` never needed more than 2 passes.

`pe_v2` remains selectable under Settings → Launch → A18 exploit path.

## Fixed: kernel panics hours or days after using Cyanide

Termination cleanup was skipped whenever no live tweaks were active. Applying
SpringBoard tweaks and closing the app therefore left the leaked sockets' PCBs on
the raw6 inpcb list with `in6p_icmp6filt` still pointing at the last kernel
address touched — a SpringBoard thread struct. `icmp6_rip6_input()` dereferences
that pointer for every inbound ICMPv6 packet, so once that thread exited the
kernel read freed memory. Confirmed by the kernel's own GZAlloc report as a
use-after-free in the threads zone.

- The cleanup guard now also fires when a KRW session exists.
- New idle parking: a watcher parks the filter at its own original allocation
  after one second of inactivity, so an abrupt kill (jetsam, force-quit, crash)
  almost never catches it pointing at live kernel state.

## Faster tweak applies

A 50 ms delay was paid before every remote ObjC message. Double Tap to Lock
spends 13 of those per Home Screen page — about 8.5 s on a 12-page device, nearly
all of it sleeping.

- Read-only selectors (`count`, `objectAtIndex:`, `respondsToSelector:`, …) no
  longer settle at all.
- New Settings → Launch → Tweak apply speed: Compatible (50 ms, default) / Fast
  (5 ms) / Fastest (only after genuinely async work).
- Remote-call cost accounting in the log.

## Other fixes

- **Kernel writes near a page boundary** could fault. `early_kwrite64` did an
  unguarded 32-byte read-modify-write; it now slides the window backwards to stay
  inside the target's page, matching Dopamine.
- **M-series slide** was computed against the wrong static base — `>> 48` yields
  `0xFFFF` for both M-series and A-series bases, so that branch never ran.
- **`pe_v2` hardening**: growable mlock table (was leaking ~127,000 IOSurfaces per
  run), `IOSurfaceCreate` failures counted rather than silently ignored, bounded
  allocation probe, and no more `exit(0)` on recoverable failures.
- **`pe_v1` A18 staging** now checks its 3 GB allocation instead of dereferencing
  NULL when it fails.
- **Chain logs survive a panic** — `fsync` (rate-limited) rather than `fflush`
  alone, which lost the whole log on the runs that most needed one.
- **ipc diagnostics** were gated on an environment variable that can never be set
  for a sideloaded app; they now follow the app's own verbose flag.

## Notes

- Tested on iPhone 16 Pro Max (A18 Pro, iOS 18.5). The M-series slide fix and the
  ipc diagnostics have not been re-verified on an M-series iPad.
- Fresh A18 runs occasionally still fault in the kernel physical aperture. That
  is inherent to the technique: the OOB read deliberately reads the physical page
  after the search mapping, and on SPTM devices a meaningful share of physical
  space is carved out and unmapped. `pe_v1` reduces the exposure; it cannot
  remove it. Once a run succeeds, parked state means later launches skip the
  exploit entirely.
