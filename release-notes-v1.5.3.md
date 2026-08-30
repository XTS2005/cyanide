# Cyanide 1.5.3

## Fixed

- **Disable App Library now works on iOS 17.** It was switched off there because
  the iOS 18 method had no effect — iOS 17 controls the App Library page through
  entirely different internals, and the properties the tweak was setting do not
  exist on that version. It now targets the right ones. Verified on iPhone 15
  Pro Max (iOS 17.3.1).

## Improved

- **SpringBoard Customizer page arrangement is roughly twice as fast.** When
  redistributing icons across pages it repeatedly re-scanned for the page to pull
  from, once per icon moved. A 12-page layout moving 114 icons should now finish
  in about half the time.
- Reading Home Screen state no longer pays the inter-call delay, which speeds up
  every tweak that walks pages — most visible on **Tweak apply speed →
  Compatible**.
