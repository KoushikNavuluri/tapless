# Tapless

Deterministic Android automation for humans. Every rule is a metro line: a trigger, optional conditions, then actions. Every run is a train with a receipt.

## What works in this build

- **Home**: your automations as lines, on/off switches, test runs and event simulation (car connects, plug in, 7:00 AM, arrive at gym, OTP SMS).
- **Builder**: type a rule in plain English. "Gym" requests use slot filling (pick gym and playlist). Other text compiles on device with a simple keyword engine.
- **Runs**: every run is logged as ran, blocked (missing access) or skipped (line paused).
- **Doctor**: reliability score and permission checks. Blocked runs point here.
- **Gallery**: add ready-made recipes in one tap.
- **Share**: copy any automation as a shareable recipe.
- Everything persists locally (`shared_preferences`, key `tapless.v1`).

AI, Android permission prompts and real device triggers are simulated in this build. Native background triggers are the next milestone.

## Build

CI (`.github/workflows/android.yml`) runs on every push to `main`:

1. `flutter create . --platforms android` to generate the Android runner
2. `flutter pub get`
3. `flutter analyze`
4. `flutter test`
5. `flutter build apk --release`
6. Publishes `app-release.apk` to GitHub Releases

Locally:

```bash
flutter create . --platforms android --org com.tapless --project-name tapless
flutter pub get
flutter analyze
flutter test
flutter run
```
