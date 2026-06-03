# Contributing to Mac-In-The-Mybag

Thanks for your interest! **MITM** is pre-alpha and moving fast — bug reports, ideas, and pull
requests are all welcome.

## Ground rules

- Be respectful — see [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
- **Found a security issue? Do _not_ open a public issue** — follow [`SECURITY.md`](SECURITY.md).
- For anything non-trivial, open an issue or a [Discussion](https://github.com/jjw0-0/Mac-In-The-Mybag/discussions) first so we can align before you build.

## Project layout (`H2`)

| Target | Platform | Responsibility |
|---|---|---|
| `SharedCore` | macOS · iOS | Protocols, codecs, connection state machine, coordinate mapping — **pure, platform-free logic; the focus of unit tests** |
| `MacOSAgent` | macOS (`#if os(macOS)`) | Screen capture, `CGEvent` injection, wake, `DisplayProvider` |
| `IOSClient` | iOS (`#if os(iOS)`) | Rendering, gestures, pairing UI, L2 harness |

Architecture and the rationale behind every major decision live in the [README](README.md).

## Dev setup

Requires Xcode 15+ / Swift 5.9+ on macOS 13+.

```sh
swift build      # all targets (macOS host; iOS-only code is #if os(iOS)-guarded)
swift test       # SharedCore unit suite
```

CI runs exactly `swift build` + `swift test` on macOS — keep both green.

## Workflow

1. Fork and branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. Keep diffs small and focused; add or update **SharedCore** tests for any logic change.
3. Ensure `swift build && swift test` pass locally.
4. Open a PR using the template and link any related issue.

## Style

- Match the surrounding Swift style; favor small, readable diffs.
- Conventional commit prefixes are encouraged: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- **Keep platform frameworks out of `SharedCore`** — it must stay pure and testable.
- No new third-party dependencies without prior discussion.

## Good first areas

- `SharedCore` pure logic + tests (coordinate mapping, connection state machine, input codecs)
- Documentation and examples
- CI / tooling improvements
