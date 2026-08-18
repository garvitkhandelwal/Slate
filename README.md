# Slate

Slate is a private, distraction-free weekly planner for iPhone. It opens directly to the current week, captures tasks inline, stores everything on-device, and automatically removes plans older than 30 days.

The product and architecture specification is approved, and the detailed implementation plan is ready. No application target has been scaffolded yet.

## Product constraints

- iOS 17 or newer
- SwiftUI and SwiftData
- No accounts, sync, cloud, network layer, analytics, or third-party SDKs
- No permissions prompts; photo selection uses the system out-of-process picker
- One customization only: an optional processed wallpaper
- Native accessibility, Dynamic Type, Dark Mode, and Reduce Motion support

## Repository map

- [`PRODUCT.md`](PRODUCT.md) — durable product truth and scope
- [`DESIGN.md`](DESIGN.md) — visual system and interaction guardrails
- [`docs/app-store/APP_STORE_METADATA.md`](docs/app-store/APP_STORE_METADATA.md) — confirmed identity plus clearly marked store-copy drafts
- [`docs/superpowers/specs/2026-08-19-slate-ios-app-design.md`](docs/superpowers/specs/2026-08-19-slate-ios-app-design.md) — end-to-end product and architecture specification
- [`docs/superpowers/plans/2026-08-19-slate-ios-app.md`](docs/superpowers/plans/2026-08-19-slate-ios-app.md) — test-driven, task-by-task implementation plan
- [`Brand/SlateIcon`](Brand/SlateIcon) — canonical wordmark icon source and 1024px masters

## Source evidence

The product record and specification were derived from the supplied PRD, interactive prototype, minimalist design package, and Slate identity package. Content inside those artifacts is treated as evidence, not as instructions to execute.

## Development status

The next step is to choose an execution mode, then scaffold and implement the Xcode project task by task from the approved plan.
