# Tapless

Tapless is a deterministic Android automation app: describe a rule, inspect the generated receipt, test-run the line, then arm it. It is designed around Android-safe, user-authored rules rather than autonomous AI actions.

## What works now
- Flutter app shell with Home, Gallery, Runs, Doctor and Settings tabs
- Local rule builder with Gym mode slot filling and simulated AI fallback
- Metro-line automation cards and test run logs
- Local persistence with `tapless.v1` and Reset demo
- QR/recipe sharing via `share_plus`
- Android-ready build pipeline publishes an APK to GitHub Releases

AI, Android permission surfaces and external integrations are honestly simulated in this first app build. Native background triggers are isolated for the next milestone.

## Build locally
```bash
flutter pub get
flutter run
flutter build apk --release
```
