# Repository Guidelines

## Project Structure & Module Organization
This repository is a Flutter mobile app for UrbanEasyFlats manager workflows. The app entry point is `lib/main.dart`, with root app wiring in `lib/src/app.dart`. Feature screens live under `lib/src/features/<feature>/`, while shared API clients, models, services, widgets, theme, and utilities live under `lib/src/core/`. Platform projects are in `android/` and `ios/`. Tests live in `test/`, assets in `assets/`, and supporting notes in `docs/`. Register any new bundled asset in `pubspec.yaml`.

## Build, Test, and Development Commands
- `flutter pub get`: install Dart and Flutter dependencies.
- `flutter run`: run the app on a connected device or emulator.
- `flutter analyze`: run static analysis using `flutter_lints`.
- `flutter test`: run all tests under `test/`.
- `flutter build apk --release`: build the Android release APK.
- `flutter build ios --release`: build the iOS release app.
- `dart run flutter_launcher_icons`: regenerate launcher icons after changing `assets/manager_logo.jpg`.

## Coding Style & Naming Conventions
Use Dart formatting (`dart format .`) and keep the default two-space indentation. Follow `analysis_options.yaml`, which includes `package:flutter_lints/flutter.yaml`. Use `snake_case.dart` filenames, `PascalCase` classes/widgets, and `lowerCamelCase` members. Prefer `const` constructors and literals where possible. Keep feature-specific UI in `lib/src/features/<feature>/`; move reusable UI to `lib/src/core/widgets/`, shared models to `lib/src/core/models/`, and backend calls to `lib/src/core/api/`.

## Testing Guidelines
The project uses `flutter_test`; existing coverage starts with `test/widget_test.dart`. Add tests in `test/` with names ending in `_test.dart`. Use `testWidgets` for screen smoke tests and interactions, and regular `test` cases for model parsing or pure utility logic. For changes touching authentication, role-based navigation, API DTOs, payments, exports, or notifications, add focused regression tests when practical. Run `flutter analyze` and `flutter test` before opening a PR.

## Commit & Pull Request Guidelines
The current Git history only shows `Initial commit`, so use short imperative commit messages such as `Add billing smoke test` or `Fix OTP retry state`. Pull requests should include a concise description, affected feature or role, linked issue/task when available, screenshots or screen recordings for UI changes, tested commands, and any configuration or release notes.

## Security & Configuration Tips
Do not commit real signing keys, API credentials, Firebase secrets, or local release files such as `android/key.properties`. Firebase setup may require regenerating `lib/firebase_options.dart` with `flutterfire configure`; verify environment-specific values before release builds.
