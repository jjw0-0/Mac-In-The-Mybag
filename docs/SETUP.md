# Setup & Build

How to build everything and reach the on-device testing stage.

## Prerequisites

- macOS 13+, Xcode 15+, Swift 5.9+
- An iPhone/iPad on iOS/iPadOS 16+ for the client (device or simulator)

## Build & test the package

```sh
swift build          # SharedCore + MacOSAgent + CVirtualDisplay + mitm-agent
swift test           # SharedCore + MacOSAgent unit suites

# iOS client (compiles the iOS-only code)
xcodebuild -scheme IOSClient -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

## Run the macOS agent

```sh
swift run mitm-agent          # listens on :7000 (override with MITM_PORT)
```

The agent requires two TCC permissions (see `Permissions`):

- **Screen Recording** — to capture the display
- **Accessibility** — to inject input events

Grant both in *System Settings → Privacy & Security*. For day-to-day use the agent is
intended to ship as a Developer-ID-signed app bundle (per the ADR); the CLI target is for
development and integration.

## Wrap the iOS client in an app

The client ships as the `IOSClient` library; create a thin app target around it:

1. New Xcode **iOS App** (SwiftUI lifecycle).
2. Add this repository as a local Swift Package dependency and link **IOSClient**.
3. Present the prebuilt screen from your `@main` app:

   ```swift
   import SwiftUI
   import IOSClient

   @main
   struct MITMApp: App {
       var body: some Scene { WindowGroup { RemoteDesktopView() } }
   }
   ```

4. Add the required Info.plist keys:
   - `NSCameraUsageDescription` — QR pairing scan
   - `NSLocalNetworkUsageDescription` — connect over the local network / hotspot
   - `NSBonjourServices` — `_mitm._udp`

## Remaining integration items (before/at device testing)

These are intentionally deferred to the device-testing stage:

- **H.264 parameter sets (SPS/PPS)** — the agent should extract SPS/PPS from the encoder's
  format description and send them so `VideoStreamDecoder.setParameterSets(sps:pps:)` can
  build the decoder format description.
- **Pairing handshake** — complete the ECDH exchange over the control channel and persist
  device trust (`DeviceTrustStore`).
- **Agent concurrency** — harden cross-queue state access in `Agent` for production.
- **Permanent limitation** — secure input fields (lock screen, passwords, Touch ID) cannot be
  driven remotely (`EnableSecureEventInput`); the client should surface this to the user.

## Where the logic is tested

`SharedCore` holds the platform-free logic (coordinate mapping, input codec, replay defense,
ABR, pairing primitives, framing, latency stats, gestures, client session) and is covered by
`swift test`. Capture/encode/inject/transport and the iOS UI are integration-tested on device.
