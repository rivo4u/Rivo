# Rivo Android Native Setup

Package/Application ID: `com.rivo.app`

The Flutter Gradle plugin is loaded from the Flutter SDK path in the machine-specific `local.properties` file. Do not commit that file. The app compiles against Android SDK 36 and targets SDK 35.

The manifest declares Internet and microphone permissions and the `rivo://login-callback` intent filter. The current sign-in implementation is native Google Sign-In followed by Supabase `signInWithIdToken`, so it does not require an OAuth redirect. Keep the callback URL registered only if a redirect-based auth flow is enabled later.

For Android Google Sign-In, create a Google Cloud Android OAuth client with package `com.rivo.app` and the signing certificate SHA-1. Run `./gradlew signingReport` from this directory to inspect debug/release certificate fingerprints. Production needs the SHA-1 for the actual release signing key, registered in the same Google Cloud project as the web OAuth client used by Supabase.

See the project [README](../README.md) for Flutter build commands and remaining backend setup.
