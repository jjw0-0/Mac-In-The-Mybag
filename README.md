<div align="center">

# 🎒 Mac-In-The-Mybag · **MITM**

### Your MacBook lives in your bag. Drive it from your iPhone.

Stream and control a **lid-closed, bag-stowed MacBook** from an iPhone or iPad —
over your phone's hotspot, with low latency, while you're on the move.

[![CI](https://github.com/jjw0-0/Mac-In-The-Mybag/actions/workflows/ci.yml/badge.svg)](https://github.com/jjw0-0/Mac-In-The-Mybag/actions/workflows/ci.yml)
[![Status](https://img.shields.io/badge/status-pre--alpha-orange)](#project-status)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B%20%7C%20iOS%2016%2B-blue)](#build)
[![Swift](https://img.shields.io/badge/swift-5.9%2B-fa7343?logo=swift)](#build)
[![Architecture](https://img.shields.io/badge/architecture-decided-success)](#architecture)

</div>

---

## Why the name?

**M**ac-**I**n-**T**he-**M**ybag. The wink at *Man-In-The-Middle* is the whole point: the only
thing allowed between your phone and your Mac is **you**. Pairing is bootstrapped **out-of-band**
through a QR code carrying an ECDH public-key fingerprint, and every byte rides **TLS 1.3** with
downgrade refused — so an actual man-in-the-middle walks away with nothing.

## The story

You're on the subway. Your MacBook is asleep in your bag. You pull out your iPhone — and there's
your full desktop. Mail, documents, the desktop-only apps mobile can't replace — responsive under
your thumb, one-handed, on a moving train.

Commercial RDP/VNC assumes desktop-to-desktop sessions on stable Wi-Fi. **MITM** is built for the
opposite: a phone-provided hotspot, a Mac kept awake inside a closed bag, and touch-first
interaction designed for movement.

## Features

| | |
|---|---|
| 📺 **Live screen** | ScreenCaptureKit + VideoToolbox, H.264 low-latency (H.265 promoted only on a clean link) |
| 👆 **Full control** | Trackpad-style cursor, tap-to-click, two-finger scroll, pinch-zoom, text input |
| 🔒 **Secure by design** | QR + ECDH pairing, TLS 1.3, per-session input re-handshake, replay-proof channel |
| 🎒 **Survives the bag** | Keeps a capture surface alive lid-closed via a virtual display, with thermal guardrails |
| 📡 **Built for the move** | QUIC path migration rides hotspot ↔ cellular handoffs without dropping the session |
| 🔁 **Self-healing** | Auto-reconnect with session recovery; adaptive bitrate degrades gracefully, never flaps |

## Architecture

A single Swift package, three targets (`H2` — separated targets + a shared core):

```
┌─────────────┐      QUIC / TLS 1.3      ┌──────────────┐
│  IOSClient  │ ◀──── video stream ────▶ │  MacOSAgent  │
│  (iOS)      │ ───── input events ────▶ │  (macOS)     │
└──────┬──────┘                          └──────┬───────┘
       │            ┌─────────────┐             │
       └──────────▶ │ SharedCore  │ ◀───────────┘
                    │ (protocols, │
                    │  codecs,    │   pure, platform-free logic — test-focused
                    │  state m/c) │
                    └─────────────┘
```

| Layer | Decision |
|---|---|
| **Transport** | QUIC (`Network.framework`) + Bonjour discovery + IP-hint fallback + path migration |
| **Video** | ScreenCaptureKit + VideoToolbox · H.264 default, H.265 one-way promotion on RTT≤50ms & ≥5Mbps |
| **Input** | `CGEvent` synthetic events (trackpad-first gesture map) |
| **Pairing** | QR + ECDH (out-of-band fingerprint) → persistent device trust |
| **Crypto** | TLS 1.3, downgrade refused, 0-RTT disabled on the input channel |
| **Lid-closed capture** | `CGVirtualDisplay` headless display (validated: 99.97% continuity, lid-closed) |
| **Adaptive quality** | RTT/loss/bandwidth ladder with hysteresis; input channel prioritized under starvation |

## Security & honest limitations

We'd rather tell you up front:

- 🚫 **Secure input fields can't be driven remotely.** macOS `EnableSecureEventInput` blocks
  synthetic events at the lock screen, password prompts, and Touch ID dialogs — by `CGEvent` *or*
  IOKit HID. This is a **permanent** OS-level boundary, not a bug we'll fix.
- 🔁 **Unattended operation is guaranteed only until a reboot.** FileVault's pre-boot login and
  TCC permission re-grants need one physical touch after a restart. We recommend disabling
  automatic update reboots; FileVault auto-login stays **off** (disk encryption wins over convenience).
- 🌡️ **Thermals are bounded.** In a sealed bag the agent caps enclosure temperature (~41°C) and
  steps down to a power-save encode before it ever cooks your battery — safety beats continuity.

## Project status

> **Pre-alpha — foundations laid, pipeline next.**

- ✅ **Kill-gate PoC passed** — lid-closed capture continuity validated (`CGVirtualDisplay`, 99.97%, ≥34 fps)
- ✅ **All 10 architecture decision gates resolved** — transport, security, thermal, scope, coordinates
- ✅ **`H2` package scaffold builds & tests green** — `SharedCore` coordinate-mapping + connection state machine under test
- 🔜 `DisplayProvider` extraction → input codec & replay defense → L2 latency harness → main capture/input pipeline

See the [roadmap](#roadmap) for what's landing next.

## Build

Requires Xcode 15+ / Swift 5.9+ on macOS 13+.

```sh
git clone https://github.com/jjw0-0/Mac-In-The-Mybag.git
cd Mac-In-The-Mybag
swift build      # builds SharedCore + MacOSAgent (+ IOSClient, iOS code guarded)
swift test       # runs the SharedCore unit suite
```

> The iOS app shell (`@main`) and on-device builds are added via an Xcode project that depends on
> this package; `swift build` targets the macOS host, so iOS-only code is `#if os(iOS)`-guarded.

## Roadmap

- [x] G-Sleep kill-gate PoC (lid-closed capture)
- [x] Architecture decision gates (DG-1 … DG-10)
- [x] `H2` package scaffold (`SharedCore` / `MacOSAgent` / `IOSClient`)
- [ ] `CGVirtualDisplayProvider` — production capture-surface provider
- [ ] Input event codec + monotonic sequence (replay defense)
- [ ] Adaptive bitrate ladder + hysteresis
- [ ] L2 instrumentation harness (end-to-end latency)
- [ ] QUIC transport + QR/ECDH pairing
- [ ] iOS client (rendering, gestures, pairing UI)
- [ ] MVP: F1–F8 core + auto-reconnect, ABR, onboarding, trackpad, thermal guard

## License

See [`LICENSE`](LICENSE).

---

<div align="center">
<sub>Built in the open. Cultivated commit by commit.</sub>
</div>
