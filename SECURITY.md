# Security Policy

**MITM** remotely controls a Mac — security is a core feature, not an afterthought. We take reports
seriously and appreciate responsible disclosure.

## Supported versions

| Version | Supported |
|---|---|
| `main` (pre-alpha) | ✅ |
| Tagged releases | — (none yet) |

## Reporting a vulnerability

**Please report privately — do _not_ open a public issue.**

- Preferred: **[GitHub Private Vulnerability Reporting](https://github.com/jjw0-0/Mac-In-The-Myphone/security/advisories/new)**
  (repo → *Security* → *Report a vulnerability*).
- We aim to **acknowledge within 72 hours** and to share a remediation timeline after triage.
- Coordinated disclosure: we'll credit you in the advisory unless you prefer to remain anonymous.

## Threat model (in scope)

- Pairing integrity — QR + ECDH out-of-band fingerprint, MITM resistance
- Transport — QUIC / TLS 1.3, downgrade refusal, 0-RTT disabled on the input channel
- Input channel — replay protection, session hijacking, device-trust revocation
- Secret handling — keys, pairing material, logs

## By-design limitations (not vulnerabilities)

These are OS-level boundaries we intentionally do **not** work around:

- **Secure input fields** (lock screen, passwords, Touch ID) cannot be driven remotely — macOS
  `EnableSecureEventInput`. This holds for both `CGEvent` and IOKit HID.
- **Unattended operation ends at reboot** — FileVault pre-boot login and TCC re-grant require one
  physical touch. FileVault auto-login stays **off** by design.

Reports about the above will be closed as *by-design* with a pointer here.
