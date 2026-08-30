# Cyanide stability & performance notes

Date: 2026-08-29
Device under investigation: **iPhone17,2 (iPhone 16 Pro Max), iOS 18.5 (22F76), A18 Pro (T8140)**

Local working-tree changes only. Nothing committed, pushed, tagged, released or uploaded.

## Outcome summary

Two long-standing instability sources and one large performance problem were identified from ten
panic logs plus a source audit. All are fixed, and Christoph has confirmed the first two on device.

| Problem | Root cause | Status |
| --- | --- | --- |
| Panics **while running Cyanide** | `pe_v2` silently failing to wire its pages, then racing on a broken contiguity assumption | Fixed — **confirmed on device** |
| Panics **hours/days later**, Cyanide not running | Termination cleanup skipped whenever no live tweaks were active, leaving a dangling `in6p_icmp6filt` | Fixed — **confirmed on device** (no panics since) |
| Tweaks slow to apply | 50 ms unconditional sleep before every remote ObjC message | Fixed + made tunable — **confirmed on device** |

## Regression fixed: pe_v2 refused to run on A18 (2026-08-29, later)

The first `pe_v2` hardening pass introduced two guards that were calibrated on a wrong assumption and
stopped the exploit from running at all. Device log:

```
i pe_v2: Allocating 131072 wired pages (2GB)...
- surface_mlock: IOSurfaceCreate FAILED at 0x12d510000 (size 0x4000) — page is NOT wired
- pe_v2: no allocatable page within 4096 probes after 0x17fffc000; stopping wiring at 100219/131072
+ pe_v2: Allocated 100219/131072 wired pages (83835 mlock failures)
- pe_v2: too many pages left unwired (83835 of 100219); aborting before the race
i surface_munlock_all: released 16384 surfaces, 83835 create failures this run
```

**16384 + 83835 = 100219.** `IOSurfaceCreate` succeeds for exactly 2^14 = **16384** surfaces per
process and then fails permanently. That is a hard ceiling, not a symptom of anything wrong — and
the original code raced happily on those ~16k wired pages, ignoring the rest.

### What was wrong

1. **`PE_V2_MLOCK_FAILURE_DIVISOR 64`** aborted staging whenever more than 1/64 of pages failed to
   wire. On a 2 GB / 131072-page run against a 16384-surface ceiling, ~87% of pages are *expected*
   to be unwired, so this aborted every single run on exactly the devices the path targets.
   The earlier reasoning — "unwired pages break the contiguity assumption, hence the aperture
   panics" — over-generalised from the panic logs into a blocking precondition.
2. **`PE_V2_MAX_FIXED_ALLOC_PROBES 4096`** (64 MB of address space) gave up staging entirely when a
   larger mapping sat in the way, truncating the run at 100219 pages.

### Fixes

1. Readiness is now judged on **pages actually wired** (`PE_V2_MIN_WIRED_PAGES`, an absolute floor
   of 1024), not on a failure ratio. On this device 16384 wired pages passes comfortably.
2. Probe exhaustion now **falls back to `VM_FLAGS_ANYWHERE`** and continues staging instead of
   stopping. Contiguity was never required — the scan finds these pages by their marker, not by
   address — so a fresh region is perfectly good. Still bounded, so the original unbounded
   `do { } while (kr != KERN_SUCCESS)` hang stays fixed.
3. New: once `IOSurfaceCreate` has failed `PE_V2_MLOCK_CEILING_STREAK` (64) times in a row, further
   attempts are skipped. That removes ~115000 guaranteed-failing syscalls per run, which also cuts
   staging time noticeably.

The diagnostics that made this findable are kept, and now report the number that actually matters:

```
[+] pe_v2: staged N/131072 pages, W wired via IOSurface, R relocations
[i] pe_v2: IOSurface ceiling reached at 16384 wired pages; skipping further surface creation
```

**Lesson for future guards on this path:** a large proportion of failed wirings is normal. Gate on
absolute wired count, never on a ratio.

## Second regression: search mappings were never resident

After the staging abort was fixed, staging completed (`staged 131072/131072 pages, 16384 wired`) but
the race never landed:

```
- physical_oob_read_mo_with_retry: giving up offset=0x4000 kr=0x1
+ pe_v2: Socket limit reached, recycling mapping 1/4 (3s settle)...
   ... x4 ...
- pe_v2: socket limit reached after 4 mapping recycles; stopping pass for safety
i surface_munlock_all: released 16384 surfaces, 69 create failures this run
```

**69 = 64 + 5.** 64 is the ceiling-detection streak; the remaining **5** are exactly the number of
search mappings created (1 initial + 4 recycles). So *every* search-mapping `IOSurfaceCreate`
failed — the 131072 staged pages had consumed the entire per-process IOSurface budget, leaving
nothing for the mappings that actually have to be resident for the physical OOB read.

That explains the symptom precisely: the marker-write loop faults the search mapping's pages in, so
some reads succeed (`successReadCount: 177`), but without `IOSurfacePrefetchPages` holding them they
are not pinned, and `physical_oob_read_mo_with_retry` keeps giving up.

### Fix

`surface_release_recent(n)` hands IOSurface slots back by releasing the most recently created
staging surfaces. When a search mapping cannot be wired, pe_v2 now releases up to
`PE_V2_SEARCH_SURFACE_RESERVE` (4096) staging surfaces — clamped so the wired count never drops
below `PE_V2_MIN_WIRED_PAGES` — and retries. Each pass munlocks its own search mapping at the end,
so in practice this only has to happen once.

**This fix is only possible because the mlock table now tracks every surface.** The original fixed
4096-entry table dropped the reference to everything past the 4096th, so those slots could never be
reclaimed — the budget was unrecoverable by construction.

### Note on history

The abort guard (`PE_V2_MLOCK_FAILURE_DIVISOR`) was present from the first pe_v2 hardening pass
onward, including the build carrying the `stringWithUTF8String` fix. Against a 16384-surface
ceiling it would have aborted on **every** run on this device, so that build cannot have completed a
fresh `pe_v2` on an A18 either — a successful run at that point would have come from parked-state
recovery rather than a fresh chain.

If these fixes do not land, the safe fallback is to revert the pe_v2 hardening wholesale to the
original code, keeping only the growable mlock table and the diagnostics.

## pe_v2 hardening REVERTED (2026-08-29, final)

`pe_v2()`, `surface_mlock()`, `surface_munlock()`, `surface_munlock_all()`, the mlock table and
`init_globals()`'s reset are now **byte-identical to the committed original** (verified by direct
comparison against `git show HEAD:`). Every change made to the A18 race path has been backed out.

### Why

The hardening was reasoned from the panic logs rather than measured, and broke a working path three
times:

1. **Abort on failure ratio.** `IOSurfaceCreate` caps at 16384 surfaces per process, so ~87% of the
   131072 staged pages are *expected* to fail to wire. Aborting above a 1/64 failure rate meant
   `pe_v2` refused to run at all.
2. **Bounded `VM_FLAGS_FIXED` probe.** Gave up staging at 100219/131072 pages when a mapping larger
   than 64 MB sat in the way.
3. **Search-mapping surface reservation.** Fixing 1 and 2 got staging to complete, but the race
   still never landed. The theory that the search mappings needed to be wired was wrong: the
   original leaks its surfaces past the 4096th and *also* leaves search mappings unwired, and it
   worked. Releasing staging surfaces to make room changed nothing (`successReadCount: 177` in both
   runs, identical failure).

Each fix addressed a real observation and still made things worse, because the premise — that
unwired pages are a fault to be guarded against — was wrong. On this device they are normal.

### What was kept

Only changes **outside** the race path, all of them confirmed on device:

- `early_kwritebuf()` — the page-boundary guard ported from Dopamine's DarkSword.
- `kexploit_krw_park_filter_safe()` / `kexploit_krw_session_active()` — the dangling
  `in6p_icmp6filt` fix.
- The termination-cleanup guard in `SettingsViewController.m` (`&& !g_kexploit_done`).
- The remote-ObjC settle work in `remote_objc.m`.

`git diff Cyanide/kexploit/kexploit_opa334.m` should now show only those two functions.

### If A18 runs still fail

The original `pe_v2` is genuinely flaky — that flakiness is what started this whole investigation.
A failed run needs a retry, not a code change. Diagnose with **logging only**; do not add guards to
this path without device measurements first.

## Panic log analysis (10 logs, 2026-08-27 → 2026-08-29)

| Class | n | Panicked task | Root cause |
| --- | --- | --- | --- |
| Fault in kernel physical aperture | 4 | `Cyanide`, ~2 GiB resident | `pe_v2`'s OOB race |
| Kernel data abort, threads zone | 3 | `kernel_task`, 0 pages | use-after-free on a freed thread |
| `initproc exited` | 2 | `launchd` | KRW state parked into pid 1 |
| watchdog timeout (92 s) | 1 | `kernel_task` | a hang |

**Class 1 identified quantitatively.** Panicked task is Cyanide with 137,633 / 134,172 / 137,766
pages resident = **2.10 GiB** — `pe_v2`'s 2 GB wiring (131,072 × 16 KB) plus app footprint. The
118,337-page one (1.81 GiB) died partway through the wiring loop. In all four `x2 = 0xf00`
(`OOB_SIZE`) and `far` is a `0xfffffff0…` physical-aperture address: the OOB copy running off the
end of a valid physical page.

**Class 2 — the kernel diagnosed it itself:**

```
Probabilistic GZAlloc Report:
  Zone    : threads
  Address : 0xffffffea78970d18
  Submap  : GEN0
  Kind    : use-after-free (medium confidence)
```

All three share the **identical static PC** `0xfffffff00854c84c` after subtracting each log's own
kernel slide — one code path, three boots. `maxpid` of 2175 / 9063 confirms long uptime, and
`processByPid` confirms Cyanide was not running.

## Root cause: class 2 (the hours/days-later panic)

1. `krw_sockets_leak_forever()` inflates `so_usecount` / `so_retaincnt` on both corrupted sockets,
   so their PCBs stay on the raw6 inpcb list **until reboot**.
2. Every kernel access leaves `rw_pcb->in6p_icmp6filt` pointing at the last address touched.
   Christoph's workflow is SpringBoard modifications, which run RemoteCall, which walks
   SpringBoard's thread list (`RemoteCall.m:1591`) — so those addresses are **thread structs**.
3. The app is closed and cleanup does not run (below), leaving the pointer dangling.
4. `icmp6_rip6_input()` dereferences `in6p_icmp6filt` for **every inbound ICMPv6 packet** — router
   advertisements and neighbour discovery, so constantly.
5. The thread exits, its zone page is reclaimed, and the next ICMPv6 packet reads freed memory.

### Why cleanup never ran

`settings_best_effort_termination_cleanup()` bailed out early:

```c
if (!settings_has_active_termination_live_tweak()) {
    return;   // never reached settings_terminal_kexploit_cleanup_sync_internal()
}
```

That guard asks "are any live tweaks running?" but the thing needing teardown is the **KRW
session**, which exists regardless of tweaks. Christoph uses **no live tweaks** — only SpringBoard
modifications, then closes the app — so it returned early every time.

The AppDelegate plumbing was already correct (`applicationWillTerminate`, the
`UIApplicationWillTerminateNotification` observer, a SIGTERM dispatch source). Only the guard was wrong.

### Fixes

1. The guard now also fires on `g_kexploit_done`.
2. **`kexploit_krw_park_filter_safe()`** points the RW PCB's filter back at its own original
   allocation — or the permanently-mapped kernel header — without ending the session. One
   `setsockopt`, reversible. Called from `applicationDidEnterBackground`, because iOS routinely
   kills backgrounded apps without `applicationWillTerminate`.

## pe_v2 defects fixed

1. **Mlock table was 32× too small.** `MAX_MLOCK` was a fixed 4096; `pe_v2` wires 2 GB one page at a
   time = 131,072 surfaces on a 16 KB-page device. Everything past the 4,096th was created and
   dropped untracked — never `CFRelease`d, unreachable by `surface_munlock_all()`. ~127,000 leaked
   IOSurfaces per run. Now grows on demand and is freed on teardown.
2. **`IOSurfaceCreate` failure was silent** — the direct cause of class 1. A NULL surface was
   ignored, so the page was quietly *not wired* while `pe_v2` continued assuming it was. Failures
   are now counted and logged, and staging **aborts before racing** if >1/64 of pages fail to wire.
3. **Unbounded allocation loop.** The contiguous `VM_FLAGS_FIXED` probe was
   `do { … } while (kr != KERN_SUCCESS);` — no cap, no timeout, no log. Bounded at
   `PE_V2_MAX_FIXED_ALLOC_PROBES`.
4. **Four `FAILURE(0)` sites called `exit(0)`** — a recoverable allocation failure terminated the
   app *with a success status* ("the app just closed"). All now fail through normal cleanup.

## Missing page-boundary guard on kernel writes

The socket primitive always moves a full 32-byte `icmp6_filter`, so an 8-byte write is really a
32-byte read-modify-write starting at `where`. If `where + 31` lands in an unmapped next page, both
halves fault.

Dopamine's `early_kwritebuf()` slides the window backwards so it ends at the last byte the caller
asked for ("this prevents errors / panics when the next page isn't mapped"). Cyanide's
`early_kwrite64()` had no such guard. Ported in as `early_kwritebuf()` in `kexploit_opa334.m`.

`early_kread()` was already safe — it passes the caller's `size` as the getsockopt `optlen`, so
`sooptcopyout` copies only that many bytes.

## Tweak apply performance

`remote_objc.m` slept **50 ms before every remote ObjC message** (`gSettleUS`, no comment
explaining it). Worked example — `darksword_tweak_double_tap_to_lock_in_session()` on a device
reporting 12 Home Screen pages:

    12 pages x 13 settles x 50 ms = 7.8 s
    + lock screen install (13)     = 0.65 s
    -------------------------------------
                                   ~8.5 s, essentially all usleep()

### Fixes

1. **Pure queries no longer settle.** `r_settle_for(selName)` checks a conservative allowlist
   (`count`, `objectAtIndex:`, `objectForKey:`, `superview`, `subviews`, `windows`,
   `isKindOfClass:`, `respondsToSelector:`, `isDock`, `iconListViewCount`, `iconListViewAtIndex:`,
   `visibleIconListViews`, `iconListViews`). Enumerating an array cannot leave SpringBoard with work
   in flight. Anything that allocates, mutates or triggers layout is deliberately excluded.
2. **Cost accounting** — `[R_OBJC] N remote messages, M settles, X ms slept in settles` every 250
   messages, plus `r_perf_report()` / `r_perf_reset()`.
3. **Settings → Launch → Tweak apply speed**: Compatible (50 ms, default) / Fast (5 ms) /
   Fastest (settle only after a `waitUntilDone:NO` dispatch).

**Confirmed on device: both Fast and Fastest apply tweaks correctly.** So the 50 ms was not
protecting the thread hijack, and **Fastest is a safe default candidate for a future build.**

Note none of the live/dynamic tweaks (`statbar`, `themer`, `livewp`, `nicebarlite`) use
`r_msg2_main_async`, so under Fastest they run with **zero** settles. Since those loops are
interval-driven, each tick completes far sooner and then sleeps — expected to *reduce* sustained
load, not increase it. Not yet tested on device.

## ClearSword: investigated and removed — do not re-attempt

A ClearSword backend was ported, hardened and wired in behind a settings picker, then **removed**
once the investigation showed it offered nothing for this device. Recorded here so it is not
re-tried.

* **It is the same exploit as DarkSword.** Verified line by line: physically contiguous PurpleGfxMem
  mapping via IOSurface, a free thread remapping over it (`VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE`)
  inside a race window, `pwritev`/`preadv` to trigger an OOB physical copy, ICMPv6 socket spray with
  the process name as oracle, `in6p_icmp6filt` corruption, 32-byte KRW via `ICMP6_FILTER`.
* **It has no A18 path.** `pe_v2()` is `// TODO: Implement` in *both* TheRealClarity's standalone
  repo and Dopamine's copy — the author had no A18 device. Writing one would mean porting Cyanide's
  own `pe_v2`, producing a second copy of DarkSword.
* **Cyanide's implementation is the more mature one.** Porting ClearSword required fixing: a surface
  mlock table that overflowed the global context on retry (bound was an `assert`, compiled out in
  Release), three unbounded loops, a free-thread deadlock, an unbounded kernel-base walk, an A18
  fall-through with no primitive, abandoned candidate PCBs left corrupted, and a use-after-free of
  shared state in `cs_run`. Cyanide already had `pe_v2`, bounded retries, page restore, gencnt
  dedup, terminal cleanup, parked-state persistence and a multi-variant process-name oracle.
* **Its only real edge is already harvested** — the page-boundary write guard, now in Cyanide.
* **The premise dissolved.** The instability was the cleanup guard and the `pe_v2` wiring bug, both
  backend-independent.

Dopamine's DarkSword was also checked: `exploit_deinit()` is `return 0;` (no cleanup at all), and
its IOSurface KRW is gated to iOS ≤ 15, so it is not used on 18.x.

## Applied after the on-device confirmation

* **Fastest is now the registered default** for `kSettingsRemoteSettleMode`. Compatible (0) and
  Fast (1) remain selectable. Note `registerDefaults` only supplies a value for keys the user has
  never set, so anyone who already touched the picker keeps their choice.
* **`pe_v2` jetsam headroom guard — TRIED AND REVERTED. Do not re-attempt in this form.**
  It consulted `os_proc_available_memory()` and capped `wiredTotalSize` accordingly. On device this
  broke the exploit: kernel primitives failed, and the run hung.

  Why it failed: `os_proc_available_memory()` reports headroom against the *process memory limit*,
  not free system RAM, so it returned far less than 2 GB on a perfectly healthy device. `pe_v2`
  then staged too few wired pages, never found one in the OOB window, and — because its outer
  search loop is an unbounded `while (true)` with no "gave up" exit — spun forever instead of
  failing. Symptoms: "kernel primitives failed" and a hang right after
  "A18/M4 detected — settling allocator".

  **The 2 GB staging figure is load-bearing and tuned. Do not scale it from any runtime memory
  query.** If jetsam pressure is revisited, the safe direction is raising the process memory limit
  or bounding `pe_v2`'s outer loop first — not shrinking the wire set.

## Known latent issue

`pe_v2`'s outer search loop is `while (true)` with exits only on success, `socketSprayStarved` or
`recycleMapping`. If staging is under-provisioned it can spin forever rather than reporting failure.
This is pre-existing (unchanged from HEAD) and is what turned the reverted headroom guard from a
degradation into a hang. Bounding it would be a safe, self-contained improvement — but it must be
done *without* touching the 2 GB staging figure.

## Remaining work

* Confirm class 2 stays gone over a longer window (days of normal use).
* Test Fastest with a live/dynamic tweak — untested, and the failure mode would differ (SpringBoard
  stutter or battery rather than a wrong apply). None of the live tweaks use `r_msg2_main_async`, so
  under Fastest they run with zero settles.
* `sbcustomizer.m` has ~20 hardcoded 50 ms sleeps in its apply path, independent of the settle.
* `kreadbuf` / `kwritebuf` in `krw.m` move 8 bytes per syscall pair when the primitive transfers 32
  — 4× more syscalls than needed. Not on the tweak hot path. Any fix must clamp each chunk to stay
  within a page, for the same reason `early_kwritebuf()` slides its window.

## Files that must not be touched accidentally

Unrelated untracked directories belonging to other projects: `Baseband/`, `ChargeLimitPlus/`,
`darksword/`, `movian/`, `movian-m7-macos-ui-test/`, `release-notes-v1.4.md`, and the
`panic-full-*.ips` logs.

## CORRECTION (2026-08-29, from an on-device log): the unwired-page theory was wrong

An actual `pe_v2` run shows:

```
[i] pe_v2: Allocating 131072 wired pages (2GB)...
[-] pe_v2: no allocatable page within 4096 probes after 0x17fffc000; stopping wiring at 102848/131072
[+] pe_v2: Allocated 102848/131072 wired pages (86464 mlock failures)
[-] pe_v2: too many pages left unwired (86464 of 102848); aborting before the race
[i] surface_munlock_all: released 16384 surfaces, 86464 create failures this run
```

102,848 staged − 86,464 failures = **exactly 16,384 successes**. 2^14 is a hard per-process
`IOSurfaceCreate` cap.

**Consequences — two of the "fixes" above were wrong and are now reverted:**

1. **`pe_v2` has always run with ~87% of its pages unwired**, silently, and worked. Unwired pages
   are normal, NOT the cause of the class-1 aperture panics. The `PE_V2_MLOCK_FAILURE_DIVISOR`
   abort therefore refused *every* run. **Removed** — `pe_v2` now bails only if it staged zero
   pages. Keep the failure counters as diagnostics; never gate behaviour on them.
2. **`PE_V2_MAX_FIXED_ALLOC_PROBES = 4096` was far too small** (64 MB of skipped address space).
   Staging truncated at 102,848/131,072 after stopping at `0x17fffc000`. Raised to `1 << 20`, which
   never fires in practice and exists only to prevent a true infinite hang.

**Also corrected:** an earlier hypothesis that `surface_munlock_all()` released 131k surfaces and
caused a hang. It only ever holds ~16,384, and the log shows teardown taking 0.33 s. The growable
mlock table is harmless — keep it.

**Class-1 aperture panics now have no confirmed cause.** Most likely the inherent raciness of the
physical OOB read. The class-2 fix (termination cleanup guard) is independent and still well
evidenced.

**Why a broken `pe_v2` can stay hidden:** once a run parks state, later runs take
`krw_persistence_recover()` and skip `pe_v2` entirely. It only resurfaces when the parked state is
gone — `[KRW] No cached state — running fresh exploit chain.`

**Process note:** none of this session's work was committed, so no state was ever restorable and
every rollback had to be reconstructed by hand. Commit each verified-good state (locally) before
making further changes.


## RESOLVED: the A18 aperture panics — use pe_v1, not pe_v2

**Confirmed on device (iPhone 16 Pro Max, iOS 18.5): the pe_v1 A18 path works, and works well.**

Nine "Unexpected fault in kernel physical aperture" panics were logged between 2026-08-28 21:22 and
2026-08-29 13:39, every one at static PC `0xfffffff0080f4a1c` with `x2 = 0xf00` (`OOB_SIZE`),
`far == x1`, and an ESR decoding to a level-3 translation fault. The earliest predates every change
made in this session, so it was never a regression.

Cause: the OOB read deliberately reads the physical page *following* the search mapping's first
page. When that page is not ours and not valid DRAM, the aperture access faults. It is a dice roll
on every read, and `pe_v2` performs thousands per run.

`pe_v1` already contained a complete A18 path that had never executed:

* `isA18Device` was declared at file scope and **never assigned true**
* `kexploit_opa334()` routed A18 devices to `pe_v2()` unconditionally

That path stages **one 3 GB wired mapping behind a single IOSurface**
(`kexploit_opa334.m:1427-1440`) plus A18-specific search geometry — the same approach ClearSword
carries as commented-out scaffolding.

| | pe_v2 | pe_v1 A18 path |
| --- | --- | --- |
| IOSurfaces requested | 131,072 | **1** |
| Per-process ceiling | 16,384 (so ~87% fail) | not approached |
| Wasted syscalls | ~115,000/run | none |
| Physical coverage | 2 GB | **3 GB** |

More owned physical memory means the adjacent page is far more often ours and valid, which is the
lever that actually governs the panic rate.

**Why the A18 code was rough in the first place:** Dopamine cannot support A18 at all, because there
is no SPTM bypass for it — kernel R/W alone gets a jailbreak nowhere on a device with SPTM, TXM and
ExclaveKit (all three visible in the panic logs, `codeSigningMonitor: 2`). So `pe_v2` is a stub
upstream not because it was hard, but because it would be pointless. Every A18 path in Cyanide is
bespoke and was never battle-tested — consistent with what was found: an abort built on a wrong
premise, `isA18Device` never wired up, a probe cap that truncated staging, and orphaned constants.

Cyanide itself needs no SPTM bypass: it takes kernel R/W and then drives SpringBoard through
RemoteCall thread hijacking and ObjC message sends — no page-table edits, no code injection.

### Selecting it

`Settings -> Launch -> A18 exploit path`, backed by `kSettingsA18ExploitPath`. Only takes effect on
a fresh chain run; a parked/recovered session skips the exploit entirely.

## Provenance of the A18 paths, and why pe_v1 works

Traced through every project that shares this exploit.

| | A18 routes to | `isA18Device` set? | `sleep(8)` | On repeated failure |
| --- | --- | --- | --- | --- |
| Dopamine DarkSword | `pe_v2()` — a `// TODO: Implement` **stub** | never | yes | n/a |
| darksword-kexploit-fun | `pe_v2()` | never | **commented out** | loops |
| Cyanide upstream (0xjohnnydev) | `pe_v2()` | never | yes | **gives up** (~100 lines of bail-outs) |
| Lara | `pe_a18()` | yes, but `pe_a18` never reads it | yes | loops forever, `sleep(20)` between rounds |
| **this fork** | **`pe_v1()`** | **yes** | skipped on pe_v1 | bounded |

The technique in `pe_v2` / `pe_a18` is identical everywhere: per-page `surface_mlock`, a fixed
`MAX_MLOCK 4096` table that silently drops the rest, unchecked `IOSurfaceCreate`, 32 MB search
mappings. The only real difference between the projects is **how long they keep retrying** — which
is a plausible explanation for anecdotal "better success rate" reports, since each retry is another
dice roll rather than a better one.

Cyanide upstream was archived 2026-08-27 (AGPL-3.0) and carries the same termination-cleanup guard
bug, so any upstream user applying SpringBoard tweaks without live tweaks has the same latent
use-after-free.

### Why a separate A18 path exists at all

`pe_v1`'s ordinary path is probabilistic: spray ~22,500 sockets and scan a 1 GB search space hoping
an `inpcb` page lands *physically adjacent* to the mapping. That works when physical memory is
fairly full. On an 8 GB device there is too much free physical memory, the spray scatters, and
adjacency collapses — hence 65,528 OOB reads per pass just to brute-force a bad hit rate.

Two different answers to that, both A18-only:

* **`pe_v1`'s A18 path — shape the memory.** Each pass pins and touches a 3 GB mapping, then
  releases it, deliberately consuming most of RAM so the remaining free pool is small and dense.
  That forces search mappings and sprayed PCBs back into physical proximity, which is why the A18
  search geometry shrinks to 4 MB (16 × 256 KB) — **240 OOB reads per pass**.
* **`pe_v2` / `pe_a18` — target instead.** Stage 2 GB of marker-tagged pages, find which one is
  physically adjacent, free exactly that page, spray a PCB into it. ~2047 reads per mapping.

Each OOB read is a chance to hit an SPTM/exclave carve-out and panic, so the read count is what
governs the panic rate. That is why `pe_v1` is the better path here, not elegance.

*(This reading is inferred from what the code does — none of it is documented or commented.)*

### A bug in Dopamine that kexploit-fun fixed

The memory-shaping loop differs between upstreams:

```c
// Dopamine
*(uint64_t *)(wiredMapping + s + PAGE_SIZE) = 0;   //  s + PAGE_SIZE
// kexploit-fun and everything downstream
*(uint64_t *)(wiredMapping + s * PAGE_SIZE) = 0;   //  s * PAGE_SIZE
```

Same loop count, different target. Dopamine's touches bytes 16384..212991 — **12 pages, 0.2 MiB**
— instead of 196,608 pages / 3.0 GiB. Its shaping is a no-op, so `pe_v1`'s A18 path would not work
on Dopamine's code at all. Nobody would have noticed, because Dopamine cannot use A18 anyway (no
SPTM bypass). We inherit the fixed version via kexploit-fun.

## Reboot

Cyanide cannot reboot directly: `reboot(2)` needs uid 0, and `ucred` is in the SPTM-protected
read-only allocator behind `proc_ro`. A developer certificate does not help — reboot needs
`com.apple.frontboard.*` class entitlements, which AMFI validates against the provisioning profile
and Apple will not issue for a normal account.

An in-app reboot button was built and then **removed** — a Shortcuts Restart action placed on the
Home Screen supersedes it entirely: one tap, works with or without KRW, and no dependence on
feature-detecting private SpringBoard selectors that were never verified. Recorded here so it is
not rebuilt.

Use instead:

* **On device:** a Home Screen shortcut running the Shortcuts *Restart* action.
* **At a Mac:** `xcrun devicectl device reboot`, or `idevicediagnostics restart`. Simplest while
  iterating.

The removed implementation is at commits `6980dfe` (SpringBoard route) and `14ada77` (Shortcuts
fallback) if it is ever wanted back.
