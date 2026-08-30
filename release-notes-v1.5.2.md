# Cyanide 1.5.2

A small release that settles the A18 memory-shaping question 1.5.1 opened, and
corrects a claim made in the 1.5.1 notes.

## Removed: the A18 memory shaping setting

1.5.1 added **Settings → Launch → A18 memory shaping** so the panic-rate
hypothesis could be tested on real hardware. It has been tested, and the result
is that no value other than 3 GB is worth offering — so the setting is gone and
the size is fixed at 3 GB.

The measurements:

| shaping | search passes | approx. OOB reads | outcome |
| ------- | ------------- | ----------------- | ------- |
| 2 GB    | 6+            | ~1275             | panicked, no target found |
| 3 GB    | 1–2           | 240–480           | succeeds in 0.6–3.4 s |
| 4 GB    | —             | —                 | killed by jetsam |

The ceiling is a hard one. `JetsamEvent-2026-08-30-145526` killed the app at
216064 pages with `killDelta=12728`, which puts the per-process limit at 203336
pages — **3.10 GiB**. That limit caps *resident* pages, and resident pages are
exactly what the shaping is: a page that has been reclaimed shapes nothing. So no
request above ~3100 MB can hold more shaping than 3 GB already does; it only adds
churn and risks the kill. 3072 MB is simply the largest round size that fits
underneath.

Going the other way measurably hurts. At 2 GB the search ran six passes and about
1275 out-of-bounds reads without finding a target, against 1–2 passes and 240–480
reads at 3 GB — three to five times the exposure, not less.

The automatic fallback to a smaller mapping stays, since `mach_vm_allocate` can
still fail on a quick relaunch and a smaller mapping beats no run at all.

## pe_v1 is the default, pe_v2 is the fallback

Naming only — no behaviour change. `pe_v1` has been the default A18 path since
1.5, but was still labelled "experimental" from when it had never been run. It is
now shown first and labelled the default, with `pe_v2` labelled the fallback, in
both the settings UI and the chain log.

Existing preferences are unaffected: the stored value keeps its original encoding,
so upgrading cannot silently switch you to the other path.

## Correction to the 1.5.1 notes

The 1.5.1 notes said that panicking runs "die on the first" search pass, and
concluded the exposure was "a fixed gamble per run" that no tuning could change.
That was drawn from a single capture, taken while the log flush interval was still
200 ms — which hid everything after the socket spray.

With the 50 ms interval shipped in 1.5.1, a 2 GB run was captured grinding through
six passes before it panicked. Panic risk scales with how long the search runs,
and search length depends on shaping quality. It is not fixed per run. That is
what makes 3 GB worth pinning rather than leaving adjustable.

## Also

- The chain log no longer prints a hardcoded "3 GB" on the A18 path lines, which
  previously made a fallback run look like a full-size one.

## Notes

Fresh A18 runs can still fault in the kernel physical aperture; the out-of-bounds
read deliberately reads the page after the search mapping, and SPTM carve-outs mean
that page is sometimes unmapped. There is no pre-check for it — the kernel faults
rather than returning an error. Once a run succeeds, parked state means later
launches skip the exploit entirely.
