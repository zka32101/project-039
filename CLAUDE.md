# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**project-039** (あんしんみち / "Anshin-Michi") is a utility app where users "paint" information about shade, rain shelter, and nighttime brightness onto maps, which is then integrated into route search. The app helps users find safe, comfortable walking routes.

**Architecture**: Three independent components
- **`app/`** — Flutter mobile app (iOS/Android)
- **`functions/`** — Firebase Cloud Functions (Node.js route search, moderation, notifications)
- **`prototype/`** — Pre-implementation route search algorithm verification (Node.js)

## Development Commands

### Testing & Quality (CI/CD Verified ✅)

All tests run automatically via GitHub Actions, but you can also run locally:

```bash
# Cloud Functions (59 tests)
cd functions && npm test

# Prototype verification (23 tests - route search algorithm)
cd prototype && npm test

# Flutter (48 tests) — requires Flutter SDK
cd app && flutter test

# All Flutter checks
cd app && flutter analyze && flutter test
```

**CI Pipeline Status**: All 12 checks passing as of main branch merge
- ✅ Flutter analyze & test (48/48 passing)
- ✅ Cloud Functions tests (59/59 passing)
- ✅ Prototype verification (23/23 passing)

### Flutter Setup

```bash
cd app
flutter pub get           # Install dependencies
flutter analyze           # Lint check (must be clean)
flutter test              # Run unit tests (48 tests)
flutter run               # Run on connected device/simulator

# With Firebase/RevenueCat configuration via dart-define
flutter run \
  --dart-define=USE_GOOGLE_MAPS=true \
  --dart-define=REVENUECAT_IOS_API_KEY=xxx \
  --dart-define=REVENUECAT_ANDROID_API_KEY=xxx
```

**Important**: This session has no network access to:
- Android SDK (`dl.google.com`) — APK build requires local environment
- Firebase Console — `android/google-services.json` and `ios/GoogleService-Info.plist` must be obtained locally
- RevenueCat dashboard — API keys must be configured locally
- Google Maps API — requires separate API key registration

All three can be mocked locally using the provided fallback services (see "Architecture: Service Pattern" below).

### Cloud Functions Setup

```bash
cd functions
npm install               # Install dependencies (uses package-lock.json for reproducibility)
npm test                  # Run 59 tests
npm run seed              # Seed Firestore with test road network (requires Firebase emulator or deployed project)
firebase deploy           # Deploy to production (requires FIREBASE_TOKEN in GitHub Secrets)
```

### Prototype Verification

```bash
cd prototype
npm install
npm test                  # Verify route search algorithm (23 tests)
npm run benchmark         # Performance check on sample data
npm run benchmark:large   # Performance check on larger dataset (60x60 grid = 3600 nodes)
```

Results are documented in `prototype/RESULTS.md` and `prototype/RESULTS_LARGE.md`.

---

## Architecture: Multi-Service Pattern

Each major service follows this pattern for **robust offline/fallback handling**:

### Example: Route Search

| Layer | Location | Purpose |
|-------|----------|---------|
| **Interface** | `app/lib/services/route_search_service.dart` | Abstract contract |
| **On-device** | `app/lib/services/route_search_service.dart` (Local*Service) | Client-side graph + Dijkstra (uses `prototype/` ported logic) |
| **Remote** | `app/lib/services/firebase/firebase_route_search_service.dart` | Calls `functions` Cloud Function via Callable |

**Fallback behavior**: If Firebase is unavailable, the app automatically uses Local*Service. No crash, no user-facing error (unless genuinely required).

Similar patterns exist for:
- **Auth** (anonymous sign-in with auto-fallback to demo mode)
- **Remote Config** (moderation settings, route weight preferences)
- **Verification** (phone SMS auth with demo fallback)
- **Subscriptions** (RevenueCat with demo purchase fallback)
- **Notifications** (FCM with no-op fallback)

### Cloud Functions Security (Client-Untrusted)

**Key principle**: Server-side verification, not client-side permission.

1. **Status fields always start as 'pending'**
   - Client creates `shadeSpots`, `brightnessSpots`, `spotComments` with status='pending'
   - `firestore.rules` enforces this; client cannot set status='approved'
   - Cloud Functions (`onShadeSpotCreated`, `onBrightnessSpotCreated`) decide actual moderation outcome

2. **Verification state via Custom Claim, not Firestore read**
   - `users/{uid}.isVerified` is set by `syncVerificationStatus` (checks Auth `phone_number` claim)
   - `firestore.rules` references Auth Custom Claim `isVerified` for `spotComments` write gate
   - Avoids read cost of checking Firestore on every comment validation

3. **Immutable sender tracking**
   - `submitterId` on all user-generated content is enforced as `request.auth.uid` in rules
   - Cannot be spoofed; used for rate limiting, vote deduplication, self-vote prevention

---

## Recent Work & Critical Changes

### ✅ CI/CD Pipelines (PR #34 - Merged)
- **GitHub Actions automation** across all three components (Flutter, Cloud Functions, Prototype)
- **Deploy workflow** triggered on `main` branch push for automatic Cloud Functions deployment
- **Documentation**: `.github/workflows/README.md` contains complete setup guide

### ✅ Bug Fixes (PR #35 - Merged)
1. **Route search error handling** (`functions/src/routeSearch.js:56-73`)
   - Added null checks when prevNode/prevEdge lookups fail during path reconstruction
   - Returns `null` on error instead of silently returning incomplete routes that cause downstream TypeErrors
   
2. **Brightness spot optimistic updates** (`app/lib/firebase/firebase_spot_submission_service.dart:94-99`)
   - Fixed: Brightness/lowFootTraffic spots were incorrectly modifying `shadowScore` (delta=0.0)
   - These spot types use backend `aggregatedBrightnessScore`, not `shadowScore`
   - Now skips shadowScore update for brightness types, aligning client UI with backend aggregation

### ⏳ Production Deployment (Waiting)
- **Deployment infrastructure ready** but requires:
  - `FIREBASE_TOKEN` (run `firebase login:ci` locally, add to GitHub Secrets)
  - `FIREBASE_PROJECT_ID` (add to GitHub Secrets)
- See `.github/workflows/README.md` for complete setup instructions

---

## Key Files & Patterns

### App Architecture

| Component | Purpose |
|-----------|---------|
| `lib/models/` | Data models (`RoadSegment`, `RouteResult`, `SpotType`, `ModerationConfig`, etc.) |
| `lib/services/` | Service layer (abstractions + Local*/Firebase implementations) |
| `lib/firebase/` | Firebase-specific implementations + bootstrap logic |
| `lib/viewmodels/providers.dart` | Riverpod state management root |
| `lib/views/` | Screens (home, paint, onboarding, verification, settings, paywall) |
| `lib/widgets/` | Reusable components (checkmark animation, notification banner, buttons) |
| `firestore.rules` | Firestore security rules (enforces status='pending' on creation, blocks self-approval) |
| `firestore.indexes.json` | Firestore composite indexes (moderation queries, rate limit windows) |

### Cloud Functions Structure

| Module | Exports |
|--------|---------|
| `src/routeSearch.js` | Dijkstra with weighted shadow scores (`searchRoute` Callable) |
| `src/shadowScore.js` | Building-based shadow calculation at 3-hour intervals |
| `src/moderationLogic.js` | Auto-approve vs. pending decision + NGword filtering |
| `src/rateLimiting.js` | Submissions/comments/votes rate limits (10-minute windows) |
| `src/spotVoting.js` | Confirm/report voting logic (thresholds for auto-promotion/demotion) |
| `src/aggregation.js` | Trust-weighted score aggregation (verified=1.5x, anonymous=0.7x) |
| `src/remoteConfigSync.js` | 1-hourly Remote Config → `config/moderation` document sync |
| `src/spatialIndex.js` | Grid-based spatial indexing (60x60 grid for 4k-node networks) |

### Prototype Validation

The `prototype/` directory contains the exact same algorithms as `functions/src/` (shared files like `geo.js`, `routeSearch.js`, `shadowScore.js`). Tests verify:
- Route search correctness (Dijkstra with shadow weighting)
- Spatial indexing (grid acceleration for nearest-node lookup)
- Shadow calculation (sun position + building occlusion)

Results in `prototype/RESULTS.md` show performance on small synthetic data; `RESULTS_LARGE.md` shows 3600-node grid performance. **Real-world validation with actual OSM data is still pending.**

---

## Important Implementation Details

### Spot Types & Moderation

- **Objective types** (tree, arcade, rain_shelter): Can auto-approve if configured
- **Brightness spot** (`brightnessSpots` collection): Uses `reasonType` ('dark' or 'low_foot_traffic')
  - 'dark' (nighttime brightness) → can auto-approve
  - 'low_foot_traffic' (pedestrian density) → **ALWAYS requires manual review** (`requiresManualReview: true`)
    - Rationale: Subjective; prone to bias/abuse. Server-side override in `functions/src/moderationLogic.js`

### Off-Device Fallback Architecture

When Firebase/RevenueCat are unavailable:
1. **Route search**: Uses client-side Dijkstra on in-app sample road network (`sample_road_network.json`)
2. **Auth**: Auto-generates anonymous user ID locally; no sign-in prompt
3. **Subscriptions**: Demo purchase mode (unlock via fake `_demo_premium` entitlement)
4. **Verification**: Demo verification with hardcoded code (`123456`)
5. **Remote Config**: Built-in defaults; no remote fetch

Users see no crash or error message—the app just works offline.

### Offline Map Caching

- `RouteResultCache` stores up to 5 recent routes (configurable)
- Used when offline or to avoid refetching the same area
- Indexed by map bounds; deduplicates same area, keeps newest
- Each entry includes freshness check to avoid stale data

### Push Notifications & Announcements

- Uses FCM **topic subscription** (`announcements` topic)
- Settings > Notifications toggle controls actual topic subscribe/unsubscribe
- No device token management server-side (topic handles distribution)
- Foreground banner queue (`ForegroundNotificationBanner`) ensures 1 notification visible at a time

---

## Testing & Verification Checklist

When making changes, verify:

- [ ] `cd functions && npm test` (59 tests pass)
- [ ] `cd prototype && npm test` (23 tests pass)
- [ ] `cd app && flutter analyze` (no warnings)
- [ ] `cd app && flutter test` (48 tests pass)
- [ ] GitHub Actions CI workflow passes (all 12 checks green)

For Firebase-dependent code, also test against Firebase emulator locally (beyond this session's scope).

---

## Deployment & Secrets

### GitHub Secrets Required for Deployment

1. **`FIREBASE_TOKEN`** — CI token from `firebase login:ci`
2. **`FIREBASE_PROJECT_ID`** — Your Firebase project ID

Set these at: `github.com/zka32101/project-039/settings/secrets/actions`

Once configured, pushing to `main` automatically triggers `deploy-functions.yml` to deploy Cloud Functions, Firestore rules, and indexes to production.

### Local Development Secrets

Do **not** commit:
- `google-services.json` / `GoogleService-Info.plist`
- RevenueCat API keys (use `--dart-define` at runtime)
- Google Maps API key (use `android/app/build.gradle` placeholder)

Add these locally and verify via fallback behavior when unavailable.

---

## Common Debugging Patterns

### "Functions not found" / Route Search Fails

**Cause**: `searchRoute` Cloud Function not deployed yet, or Firestore `roadSegments` collection empty.

**Fix**: 
1. Ensure `functions/README.md` seeding step is complete (`npm run seed`)
2. Or use fallback: App auto-falls back to `LocalRouteSearchService` using `sample_road_network.json`

### Flutter Lint Failures

**Recent fixes** in this session:
- Replaced `Color.withValues(alpha: X)` with `Color.withOpacity(X)` (Flutter 3.22 compatibility)
- Fixed `BuildContext` usage across async gaps (save `Navigator` reference before await)
- Import path corrections (`spotType.dart` relative imports)

Run `flutter analyze` before committing to catch similar issues.

### Test Timeouts in Flutter

**Known issue** (fixed): `rootBundle` Future caching across multiple `testWidgets` in same file causes `pumpAndSettle` timeout on 2nd+ test. 

**Solution**: Wrap each test's `rootBundle` call in a unique future cache scope, or use `testBinding.window.physicalSizeTestValue` isolation.

---

## Recommended Next Steps

1. **Set up Firebase locally**: Create a project, deploy Firestore rules & functions, seed road network
2. **Configure GitHub Secrets** for production deployment
3. **Real-world algorithm validation**: Run `prototype/` against actual OSM data via Overpass API (currently uses synthetic data)
4. **Android APK build**: Requires local `flutter create .` + Android SDK; CI/CD cannot build APK due to network policy
5. **iOS build & TestFlight**: Requires Xcode, Apple Developer account, APNs certificate

---

## References

- **Design & Planning**: `anshinmichi_sekkei_v1_0.md` (internal design doc)
- **Code Handoff**: `anshinmichi_code_handoff_v1_0.md` (internal requirements)
- **Detailed Docs**: `app/README.md`, `functions/README.md`, `prototype/README.md`
- **Workflows**: `.github/workflows/README.md` (CI/CD setup guide)
- **Firestore Security**: `app/firestore.rules` (enforces untrusted-client model)
