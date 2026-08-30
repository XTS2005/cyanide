# Cyanide 1.5.2

## Removed

- **Settings → Launch → A18 memory shaping.** The size is now fixed at 3 GB.
  Larger values gave no benefit and could get Cyanide killed; smaller values made
  fresh runs more likely to panic, not less. There was no setting worth keeping.

## Changed

- **`pe_v1` is now labelled the default and `pe_v2` the fallback** under
  Settings → Launch → A18 exploit path. Naming only — `pe_v1` has been the
  default since 1.5, but was still described as experimental. Your current
  selection is unaffected by the update.

## Fixed

- The chain log no longer reports a fixed "3 GB" on the A18 path lines, which
  could make a reduced-size run look like a full-size one.
