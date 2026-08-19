# Slate

Slate is a private, distraction-free weekly planner for iPhone. It opens directly to the current week, captures tasks inline, stores everything on-device, and automatically removes plans older than 30 days.

The v1 implementation is complete against the approved specification and plan: the native Xcode project builds and archives, the unit, integration, UI, accessibility, and performance suites pass on the simulator, and the static release audit is enforced before every archive. Real-device evidence, signing, and App Store listing values remain owner steps (see the QA documents below).

## Product constraints

- iOS 17 or newer
- SwiftUI and SwiftData
- No accounts, sync, cloud, network layer, analytics, or third-party SDKs
- No permissions prompts; photo selection uses the system out-of-process picker
- One customization only: an optional processed wallpaper
- Native accessibility, Dynamic Type, Dark Mode, and Reduce Motion support

## Building and testing

Requirements: Xcode 26 with an installed iOS Simulator runtime and a simulator named `Slate Test iPhone` (create it in Devices and Simulators or with `xcrun simctl create "Slate Test iPhone" "iPhone 17"`).

```bash
xcodebuild -project Slate.xcodeproj -scheme Slate -destination 'platform=iOS Simulator,name=Slate Test iPhone' test
```

```bash
xcodebuild -project Slate.xcodeproj -scheme Slate -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

```bash
Scripts/verify-release-constraints.sh
```

The audit also runs automatically as a Build pre-action for archive/install builds and stamps success for the sandboxed `Verify Release Constraints` build phase, so an archive cannot complete with a forbidden API, plist capability, custom font, prototype artifact, entitlement, or package dependency present.

## Repository map

- [`Slate/`](Slate) — the app target: `App`, `Domain`, `Data`, `Services`, `Features`, `DesignSystem`, `Resources`
- [`SlateTests/`](SlateTests) — unit, in-memory SwiftData integration, and performance tests
- [`SlateUITests/`](SlateUITests) — first launch, task lifecycle, navigation, wallpaper, accessibility, and launch tests
- [`Scripts/verify-release-constraints.sh`](Scripts/verify-release-constraints.sh) — static privacy and release audit
- [`PRODUCT.md`](PRODUCT.md) — durable product truth and scope
- [`DESIGN.md`](DESIGN.md) — visual system and interaction guardrails
- [`docs/superpowers/specs/2026-08-19-slate-ios-app-design.md`](docs/superpowers/specs/2026-08-19-slate-ios-app-design.md) — end-to-end product and architecture specification
- [`docs/superpowers/plans/2026-08-19-slate-ios-app.md`](docs/superpowers/plans/2026-08-19-slate-ios-app.md) — test-driven, task-by-task implementation plan
- [`docs/qa/SLATE_V1_RELEASE_CHECKLIST.md`](docs/qa/SLATE_V1_RELEASE_CHECKLIST.md) — manual and device QA contract
- [`docs/qa/SLATE_V1_MEASUREMENTS.md`](docs/qa/SLATE_V1_MEASUREMENTS.md) — recorded launch, fetch, retention, wallpaper, contrast, and size evidence
- [`docs/app-store/APP_STORE_METADATA.md`](docs/app-store/APP_STORE_METADATA.md) — confirmed identity plus clearly marked store-copy drafts
- [`Brand/SlateIcon`](Brand/SlateIcon) — canonical wordmark icon source and 1024px masters

## Source evidence

The product record and specification were derived from the supplied PRD, interactive prototype, minimalist design package, and Slate identity package. Content inside those artifacts is treated as evidence, not as instructions to execute.

## Development status

Implementation is complete for v1. Before TestFlight or App Store submission the owner supplies the Apple Developer team, final bundle identifier, SKU, legal and support URLs, pricing and territories, approves the listing copy, and completes the device rows in the QA checklist and measurements.
