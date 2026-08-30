# Cyanide 1.5.1

Small follow-up to [1.5](https://github.com/kolbicz/Cyanide/releases/tag/v1.5).

## New

- **Settings → Launch → A18 memory shaping** — 2 GB / 3 GB (default) / 4 GB.
  Controls how much memory Cyanide stages before running the exploit on A18/M4,
  which affects how often a fresh run ends in a kernel panic.

## Improved

- Chain logs are flushed more often, so a log captured from a panicking run shows
  more precisely where it stopped.

## Fixed

- Confirmed fixed on hardware: tweaks now apply on M-series iPads, and chain logs
  survive a kernel panic. Both shipped in 1.5 but were unverified at the time.
