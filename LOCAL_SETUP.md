# Local Development Setup Guide

This guide covers setting up project-039 (あんしんみち) for local development with full Firebase integration, emulator testing, and deployment.

## Prerequisites

- **Node.js** 20.x or later (for Cloud Functions and Prototype)
- **Flutter SDK** 3.22.x or later (for app)
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Git** (already have it)
- **macOS/Linux** (Windows requires WSL2 for Firebase emulator)

---

## Part 1: Firebase Project Setup

### 1.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project" → name it `project-039-local` or similar
3. **Enable Google Analytics** (optional but recommended)
4. Create project

### 1.2 Enable Required Services

In Firebase Console, go to **Build** section and enable:

- ✅ **Authentication** → Sign-in method
  - Enable **Anonymous** (default, already on)
  - Enable **Phone Number** (for SMS verification)
    - Set up phone numbers for testing (Firebase emulator accepts any test number)
  
- ✅ **Cloud Firestore** → Create database
  - Start in **test mode** (for development only; use production rules before deploying)
  - Location: choose region closest to you
  
- ✅ **Cloud Functions** → already enabled with Firestore
  
- ✅ **Cloud Storage** → Create bucket (needed for some operations)
  
- ✅ **Remote Config** → Create config
  - You'll populate this with defaults in `firestore.rules`
  
- ✅ **Cloud Messaging** → Already enabled

### 1.3 Configure Phone Number Testing

In **Authentication > Phone Number**:
1. Click "Phone numbers for testing"
2. Add test numbers with test codes (e.g., `+1 555-0100` → `123456`)
3. These will auto-verify in dev/emulator without actually sending SMS

---

## Part 2: Firebase Emulator Suite

### 2.1 Install and Start Emulator

```bash
# Install Firebase emulator
firebase emulators:start --project=project-039-local

# First run will download emulators (~500MB)
# Subsequent runs start instantly
```

This starts:
- **Firestore Emulator** (localhost:8080)
- **Auth Emulator** (localhost:9099)
- **Cloud Functions Emulator** (localhost:5001)
- **Pub/Sub Emulator** (localhost:8085)

### 2.2 Configure Emulator in Cloud Functions

Update `functions/.env.local` (create if doesn't exist):

```bash
# Point to emulator
FIRESTORE_EMULATOR_HOST=localhost:8080
FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
```

Run tests against emulator:

```bash
cd functions
export FIRESTORE_EMULATOR_HOST=localhost:8080
export FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
npm test
```

All 59 tests should pass.

### 2.3 Seed Test Data

```bash
cd functions
npm run seed  # Populates emulator with sample road network
```

Check `seed/seedRoadNetwork.js` for what gets created.

---

## Part 3: Flutter App Local Setup

### 3.1 Get Dependencies

```bash
cd app
flutter pub get
```

This installs all packages listed in `pubspec.yaml`.

### 3.2 Create Platform Directories

```bash
flutter create .
```

This generates `android/` and `ios/` directories (required for building).

**⚠️ Important**: Check that directories were created:
```bash
ls -la | grep -E "^d.*(android|ios)"
```

### 3.3 Configure Firebase Locally

#### Android

1. Get your **Google Service Account Key**:
   - Firebase Console > Project Settings > Service Accounts
   - Click "Generate New Private Key" → downloads JSON
   
2. Convert to Android format:
   ```bash
   # Firebase Console > Project Settings > Your Apps (Android)
   # Download google-services.json
   ```
   
3. Place file:
   ```bash
   cp google-services.json app/android/app/
   ```

4. Update `android/app/build.gradle`:
   ```gradle
   // At the top
   apply plugin: 'com.google.gms.google-services'
   
   // In dependencies
   dependencies {
       classpath 'com.google.gms:google-services:4.3.15'
   }
   ```

#### iOS

1. Get your **GoogleService-Info.plist**:
   - Firebase Console > Project Settings > Your Apps (iOS)
   - Download plist file

2. Place file in Xcode:
   ```bash
   cp GoogleService-Info.plist app/ios/Runner/
   ```

3. Update `ios/Podfile`:
   ```ruby
   # At the top, set minimum version
   platform :ios, '14.0'
   
   # In post_install hook
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       flutter_additional_ios_build_settings(target)
     end
   end
   ```

### 3.4 Point App to Emulator

Create `app/lib/firebase/firebase_bootstrap.dart` update:

```dart
// During development, point to emulator:
if (kDebugMode) {
  try {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  } catch (e) {
    // Emulator already enabled or unavailable
  }
}
```

### 3.5 Run Flutter App

```bash
cd app
flutter run

# Or on iOS simulator
flutter run -t lib/main.dart -d all
```

**Verify Emulator Connection**:
- App starts without crashing
- "Home" screen shows route (using sample road network)
- Sign in works (anonymous auto-signin)
- No Firebase errors in console

---

## Part 4: RevenueCat Setup (Optional)

### 4.1 Create RevenueCat Project

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Create new project
3. Create "Premium" entitlement
4. Create product linked to entitlement

### 4.2 Configure API Keys

Get your **Public API Keys**:
- iOS: API Key from dashboard
- Android: API Key from dashboard

Run app with keys:

```bash
cd app
flutter run \
  --dart-define=REVENUECAT_IOS_API_KEY=your_ios_key \
  --dart-define=REVENUECAT_ANDROID_API_KEY=your_android_key
```

**Without Keys**: App automatically uses `LocalSubscriptionService` (demo mode).

---

## Part 5: Google Maps (Optional)

### 5.1 Get API Key

1. [Google Cloud Console](https://console.cloud.google.com) → Create project
2. Enable **Maps SDK for Android** and **Maps SDK for iOS**
3. Create API Key (restrict to iOS/Android bundled IDs)

### 5.2 Configure Platforms

#### Android

In `android/app/src/main/AndroidManifest.xml`:

```xml
<application>
  <meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="your_api_key"/>
</application>
```

In `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21  // Maps requires 21+
    }
}
```

#### iOS

In `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  GMSServices.provideAPIKey("your_api_key")
  GeneratedPluginRegistrant.register(with: self)
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

In `ios/Podfile`:

```ruby
platform :ios, '14.0'  # Maps requires 14.0+
```

### 5.3 Run with Maps

```bash
flutter run --dart-define=USE_GOOGLE_MAPS=true
```

---

## Part 6: Deploy Cloud Functions Locally

### 6.1 Deploy to Emulator

```bash
firebase emulators:exec --only=firestore,auth,functions,pubsub \
  "cd functions && npm test"
```

### 6.2 Deploy to Firebase Staging

```bash
cd functions

# Requires: FIREBASE_TOKEN in environment or local Firebase login
firebase deploy --only functions --project=project-039-local
```

Then test via Flutter app's `RemoteRouteSearchService`.

---

## Part 7: Full Integration Testing

### 7.1 All Tests in Local Environment

```bash
# Terminal 1: Start emulator
firebase emulators:start --project=project-039-local

# Terminal 2: Test Cloud Functions
cd functions
npm test  # Should all pass

# Terminal 3: Test Prototype
cd prototype
npm test  # Should all pass

# Terminal 4: Test Flutter
cd app
flutter test  # Should all pass
```

### 7.2 Manual Testing Flow

1. **Launch App**:
   ```bash
   cd app
   flutter run --dart-define=USE_GOOGLE_MAPS=true
   ```

2. **Verify Screens**:
   - ✅ Onboarding (3 pages)
   - ✅ Location permission request
   - ✅ Home screen loads route
   - ✅ Settings → Account shows anonymous user
   - ✅ Settings → Paywall shows demo purchase

3. **Test Posting**:
   - Click paint button → select spot type (tree) → draw on map → submit
   - Watch for "Submission confirmed" animation
   - Verify in Firestore console: new document in `shadeSpots`

4. **Test Verification** (if Phone Auth enabled):
   - Settings → Account → Verify phone number
   - Enter test number (e.g., `+1 555-0100`)
   - Enter test code (e.g., `123456`)
   - Verify in Firestore: `users/{uid}.isVerified = true`

---

## Part 8: GitHub Secrets for Production

### 8.1 Generate Firebase Token

```bash
firebase login:ci --no-localhost
```

Returns a long token string. Copy it.

### 8.2 Add to GitHub Secrets

1. Go to `github.com/zka32101/project-039/settings/secrets/actions`
2. Click "New repository secret"
3. Name: `FIREBASE_TOKEN`
   Value: (paste the token)
4. Name: `FIREBASE_PROJECT_ID`
   Value: (your actual Firebase project ID)

### 8.3 Verify Deployment

Push to `main`:

```bash
git push origin main
```

GitHub Actions will run `deploy-functions.yml`:
- Tests will run
- Firebase CLI will deploy functions, rules, indexes
- Check Actions tab for success ✅

---

## Troubleshooting

### Firebase Emulator Won't Start

**Error**: `Error: spawn firebase: ENOENT`

```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Verify installation
firebase --version
```

### Flutter App Can't Connect to Emulator

**Error**: `Failed to initialize Firebase`

```dart
// Add logging to firebase_bootstrap.dart
debugPrint('Connecting to Firestore emulator...');
await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
debugPrint('Connected!');
```

Then check:
- ✅ Emulator is running (`firebase emulators:start`)
- ✅ Port 8080 is not blocked by firewall
- ✅ `--dart-define` flags passed correctly

### Cloud Functions Tests Timeout

**Error**: `Tests timeout waiting for Firestore writes`

```bash
# Ensure emulator is running before tests
firebase emulators:start --project=project-039-local &
sleep 5  # Wait for emulator to be ready
npm test
```

### Phone Verification Not Working

**In Emulator**: Test codes auto-verify instantly. No SMS needed.

**In Production**: Firebase will send real SMS. Configure SMS Provider in Firebase Console:
- Default: Firebase Identity Platform
- Alternative: Twilio (if you set up Twilio integration)

---

## Development Workflow

### Daily Development Loop

```bash
# Terminal 1: Emulator
firebase emulators:start --project=project-039-local

# Terminal 2: Watch Flutter
cd app
flutter run -v

# Terminal 3: Edit and test manually
# (Make changes in your editor)

# When done: Push changes
git add .
git commit -m "Feature: ..."
git push origin main
```

### Before Committing

```bash
# Run all tests
cd functions && npm test
cd ../prototype && npm test
cd ../app && flutter analyze && flutter test

# All must pass ✅
```

### Deployment to Production

1. **Ensure Firebase Secrets are set** in GitHub
2. **Create a PR** with your changes
3. **Merge to main**
4. **GitHub Actions** automatically deploys via `deploy-functions.yml`
5. **Monitor** in [Firebase Console](https://console.firebase.google.com)

---

## References

- [Firebase Emulator Suite Docs](https://firebase.google.com/docs/emulator-suite)
- [Flutter Firebase Integration](https://firebase.flutter.dev)
- [Cloud Functions Testing](https://firebase.google.com/docs/functions/testing/test-overview)
- [RevenueCat Documentation](https://docs.revenuecat.com)
- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)

---

## Need Help?

1. Check `CLAUDE.md` for architecture overview
2. Read `.github/workflows/README.md` for CI/CD details
3. Review `app/README.md`, `functions/README.md`, `prototype/README.md` for component specifics
4. Check logs: `firebase emulators:start --project=project-039-local --log-level=debug`
