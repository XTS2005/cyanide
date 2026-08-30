> **Supported:** iPhone / iPad on iOS/iPadOS `17.0 – 18.7.1` or `26.0 – 26.0.1`.
> **Not supported:** iPhone 17 (A19 / A19 Pro) and M5 — Memory Integrity Enforcement.
> Any other device on a supported version works. [Details](https://github.com/kolbicz/Cyanide#supported-devices)

# Cyanide 1.5.5

## New

- **Unsupported devices are now turned away with a reason.** On iPhone 17 or
  newer, and on the M5 iPad Pro, Apple's Memory Integrity Enforcement blocks the
  kernel exploit Cyanide is built on. Those devices previously started a run and
  failed part-way with no explanation; they now say so up front.

## Documentation

- The [README](https://github.com/kolbicz/Cyanide#supported-devices) states which
  iOS versions and devices are supported, and every release page carries a short
  version of the same. iOS 15 and 16 are deliberately out of scope — every device
  on those versions is jailbreakable with
  [Dopamine](https://github.com/opa334/Dopamine). iOS 17 is supported in full,
  including versions a jailbreak already covers, because Cyanide does not
  jailbreak the device: tweaks are applied in memory for the current boot, so
  apps that refuse to run on a jailbroken device keep working.
