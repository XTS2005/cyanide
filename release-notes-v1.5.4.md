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
