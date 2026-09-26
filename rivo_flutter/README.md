# Rivo

Flutter Android app for Rivo. The supplied UI screens and sheets are preserved.

## Project Status

- Google Sign-In uses the native `google_sign_in` flow and exchanges its ID token with Supabase Auth.
- The auth gate routes authenticated users to the existing Home screen.
- `RivoApi` connects profiles, rooms, mic seats, room chat, Moments, direct messages, notifications, settings, gifts, wallets and social actions to Supabase.
- Room gifts use the `send_gift` RPC for atomic wallet debits and ledger writes. The feature migration adds the missing Moments table, conditional RLS policies and Realtime publication for DMs and room gifts; review it against the existing project schema before applying it.
- Coin purchases are intentionally unavailable until a payment provider is configured. The app does not simulate payment success.
- No LiveKit or WebRTC SDK/session configuration is included. Room UI reports live audio as unavailable.

## Requirements

- Flutter 3.47 or compatible, with Dart 3.13 or compatible.
- JDK 17 or newer.
- Android SDK 36. Flutter/Gradle may install the required Android build tools and CMake components on the first build.

## Build

Run these commands from this directory:

```sh
flutter pub get
flutter analyze
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.
The Android application ID is `com.rivo.app`.

## Supabase

The Supabase project URL and client-side publishable key are configured in `lib/main.dart`. A publishable key is intended for client apps; never add a service-role or secret key. Configure Google as an enabled Supabase Auth provider and keep its server/web OAuth client ID aligned with `googleWebClientId` in `lib/main.dart`.

Apply the migrations in `supabase/migrations` in order using the Supabase SQL Editor. The profile migration creates a profile row for new Auth users and backfills existing users. The feature migration reuses the existing gifts, wallet, transaction, message, notification and settings tables, and expects their conventional owner/transaction columns; verify those columns before applying it to a project whose schema differs.

## Google Android Sign-In

Create an Android OAuth client in the same Google Cloud project, using package name `com.rivo.app` and the SHA-1 fingerprint for each signing certificate. The local debug certificate can be inspected with:

```sh
cd android
./gradlew signingReport
```

Register the debug SHA-1 for local builds and the release signing SHA-1 for production. The Google Cloud and Supabase dashboards require a project administrator; credentials are not needed in this repository.

The manifest includes `rivo://login-callback` for redirect-based OAuth integrations. The current native Google ID-token flow does not use that callback URL.

## Tests

Run `flutter analyze`, `flutter test` and `flutter build apk --debug` from this directory. Widget tests cover bottom navigation and the no-fake-payment Add Coins state.
