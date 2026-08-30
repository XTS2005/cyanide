> ### Supported devices
> **iPhone / iPad on iOS/iPadOS `17.0 – 18.7.1` or `26.0 – 26.0.1`.**
> Not supported: iOS `18.7.2 – 25.x`, `26.1+`, anything older than 17.0 — and the
> **iPhone 17 family (A19 / A19 Pro)** and **M5**, where Memory Integrity
> Enforcement blocks the exploit. Any other iPhone or iPad on a supported
> version should work; there is no device whitelist.
> iOS 15 and 16 are out of scope by choice — they are covered by
> [Dopamine](https://github.com/opa334/Dopamine), so Cyanide has nothing to add there.

# Cyanide 1.5.4

## Fixed

- **The exploit no longer re-runs on every launch (iOS 17).** Cyanide is meant to
  park its kernel state so later launches skip the exploit entirely, but the
  hand-off was failing every time — so each run raced the kernel allocator again
  from scratch. Launches after the first are now near-instant.

  This also matters on A18: every fresh run is a chance of a kernel panic, and
  most runs no longer need one.

## Removed

- **Signal Readouts, TypeBanner, Notification Island and IPA Decryptor.** All four
  were marked in-development and could not be installed. They are gone from the
  installer along with their settings sections.

## Improved

- Several parts of Cyanide were writing diagnostics that never reached the log,
  including the Drag Coefficient tweak. Logs are more complete — and noticeably
  chattier — when something needs investigating.




