# Cyanide 1.5.1

Small follow-up to 1.5. See the [1.5 notes](https://github.com/kolbicz/Cyanide/releases/tag/v1.5)
for the substantial changes — this adds one setting and sharpens diagnostics.

## New: A18 memory shaping size

**Settings → Launch → A18 memory shaping — 2 GB / 3 GB (default) / 4 GB.**

On the `pe_v1` A18 path, Cyanide fills a block of memory before racing so that the
physical page next to its search window is more likely to be its own. That is the
only thing that meaningfully affects how often a fresh run ends in a kernel panic:
the out-of-bounds read deliberately reads the page after the search mapping, and it
faults when that page is neither ours nor backed.

More shaping means better odds, but it can fail to allocate and puts other apps
under memory pressure. It now falls back to a smaller size automatically instead of
failing the run, so over-reaching degrades rather than blocks. 3 GB remains the
tested default; treat 4 GB as an experiment.

## Confirmed since 1.5

- **M-series iPad RemoteCall works.** The `t1sz` / `VM_MAX_KERNEL_ADDRESS` fix
  shipped in 1.5 was derived from a device log rather than a run. It has now been
  verified on hardware: `init_remote_call` succeeds, so tweaks apply on M-series
  iPads for the first time.
- **Chain logs survive a kernel panic.** The `F_FULLFSYNC` change works — a
  panicking run now leaves a usable log instead of a 0-byte file.

## Other

- Log flush interval tightened from 200 ms to 50 ms, so a log captured from a
  panicking run pins down more precisely where it stopped.

## Notes

Fresh A18 runs can still fault in the kernel physical aperture. Measurements from
this release cycle: successful runs take 1–2 search passes, panicking runs die on
the first. That means the exposure is a fixed gamble per run rather than something
that accumulates, and no amount of tuning changes the odds per attempt. Once a run
succeeds, parked state means later launches skip the exploit entirely.
