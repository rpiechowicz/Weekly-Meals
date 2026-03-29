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

Current project default points to the production backend URL in the Xcode project build settings.

## Runtime notes

- URL scheme: `weeklymeals://`
- Bundle identifier: `rpiechowicz.weekly-meals`
- Push token registration happens automatically after app launch and login
- APNs testing requires a physical iPhone

## Current auth note

The current app build still uses the backend dev-login flow. That means the target backend environment must keep `/auth/dev` available until real auth is shipped.

## CI

GitHub Actions workflow: [`ios-ci.yml`](./.github/workflows/ios-ci.yml)

The workflow resolves packages and builds the simulator target without code signing.

## Related backend docs

- [Backend README](../weakly-meals-backend/README.md)
- [`APNS_SETUP.md`](../weakly-meals-backend/APNS_SETUP.md)
- [`DEPLOYMENT.md`](../weakly-meals-backend/DEPLOYMENT.md)
