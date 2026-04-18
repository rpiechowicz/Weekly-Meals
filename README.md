# Weekly Meals iOS

SwiftUI client for Weekly Meals. The app covers recipes, weekly planning, calendar view, shopping list flows, household collaboration, realtime sync, and local notification handling.

## Requirements

- Xcode 17+
- iOS Simulator or physical iPhone
- Running backend API

## Open and build

Open:

- [`weekly meals.xcodeproj`](./weekly%20meals.xcodeproj)

CLI build:

```bash
xcodebuild -project "weekly meals.xcodeproj" -scheme "weekly meals" -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO
```

## Backend configuration

The app resolves `API_BASE_URL` in this order:

1. process environment
2. Info.plist / build setting
3. built-in production fallback

Checked-in defaults stay on production.

During `Debug` builds, a build phase rewrites the built app's `Info.plist` like this:

- branch `master` or `main`: `https://api.weeklymeals.app`
- any other local branch: `http://localhost:3000`

`Release` builds always use `https://api.weeklymeals.app`.

For local backend development on a physical iPhone, override `API_BASE_URL` in your local Xcode scheme or launch environment and use your Mac's LAN IP (for example `http://192.168.x.x:3000`) rather than `localhost`, which resolves to the phone itself.

## Runtime notes

- URL scheme: `weeklymeals://`
- Bundle identifier: `rpiechowicz.weekly-meals`
- Push token registration happens automatically after app launch and login
- APNs testing requires a physical iPhone

## Current auth note

The current app build uses Sign in with Apple and posts the resulting token to `POST /auth/apple`.

## CI

GitHub Actions workflow: [`ios-ci.yml`](./.github/workflows/ios-ci.yml)

The workflow resolves packages and builds the simulator target without code signing.

## Related backend docs

- [Backend README](../weakly-meals-backend/README.md)
- [`APNS_SETUP.md`](../weakly-meals-backend/APNS_SETUP.md)
- [`DEPLOYMENT.md`](../weakly-meals-backend/DEPLOYMENT.md)
