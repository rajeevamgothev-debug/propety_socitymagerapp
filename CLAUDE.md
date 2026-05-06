# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UrbanEasyFlats Manager — a native Flutter mobile app for property managers (VendorType 2) and society managers (VendorType 1). Calls backend APIs directly via an HTTP API client with automatic session/API-key refresh. Supports OTP-based authentication, role-based navigation, push notifications (FCM), PDF generation, Excel export, and Razorpay payments.

## Full-Stack Context

This app is the mobile client in a three-part system. The sibling repos live one directory up (`../`):

| Repo | Role | Tech | Runs on |
|------|------|------|---------|
| `urbaneasyflats_nodejs` | Backend API | Express + Mongoose (MongoDB Atlas) | `api.urbaneasyflats.com` (port 3000) |
| `urbaneasyflats_web` | Web frontend | React 18 + Vite + TypeScript + Tailwind | `urbaneasyflats.com` (port 4000) |
| **this repo** | Mobile app | Flutter (Dart, Material 3) | Android/iOS |

**Backend API patterns:** All routes are POST-only. Auth credentials (`ApiKey`, `SessionID`, `VendorID`) are sent in the request body, not headers. The API client (`api_client.dart`) handles auto-refresh of expired sessions (response code 1) and invalid API keys (response code 2).

**Multi-site:** The web frontend serves two brands (UrbanEasy and Stayzen) from one codebase via env-based config and feature flags.

## Build & Run Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run on connected device/emulator
flutter build apk --release  # Build Android release APK (uses android/key.properties for signing)
flutter build ios --release  # Build iOS release
flutter analyze              # Run static analysis (flutter_lints)
flutter test                 # Run tests
```

Generate launcher icons after changing `assets/manager_logo.jpg`:
```bash
dart run flutter_launcher_icons
```

Firebase push notifications require running `flutterfire configure` to generate a real `lib/firebase_options.dart`.

## Architecture

Feature-based modular structure under `lib/src/`:

```
lib/
  main.dart                          # Entry point (Firebase init + runApp)
  firebase_options.dart              # Firebase config (placeholder — run flutterfire configure)
  src/
    app.dart                         # Root widget, auth state machine, role resolution
    core/
      api/                           # 23 service files (api_client, auth, vendor, billing, etc.)
      models/                        # app_models.dart (enums, domain models), api_models.dart (DTOs)
      theme/                         # app_theme.dart (Material 3, primary #2563EB)
      widgets/                       # 6 reusable widgets (CustomCard, CustomButton, etc.)
      data/                          # mock_repository.dart
      services/                      # push_notification_service.dart
      utils/                         # PDF/Excel generation utilities
    features/
      auth/                          # login_page, otp_page, profile_setup_page
      landing/                       # landing_page, public_discovery_section, public_properties_page
      shell/                         # app_shell (role-based tabs), role_selection_page
      dashboard/                     # dashboard_page
      properties/                    # properties_page, property_enquiries_page
      rental_contracts/              # rental_contracts_page
      billing/                       # billing_page (multi-role: rental + society bills)
      support/                       # support_page (tickets with image upload)
      communication/                 # communication_page (announcements)
      society/                       # society_management_page
      residents/                     # residents_page
      security/                      # security_page
      block/                         # block_issues_page, block_security_page
      wallet/                        # bank_wallet_page
      visitors/                      # visitors_page, my_visits_page
      residence/                     # residence_overview_page
      reports/                       # reports_page
      audit/                         # audit_logs_page
      bookings/                      # bookings_page
      tenant/                        # tenant_contracts_page, tenant_security_page
      notifications/                 # notifications_page
      settings/                      # settings_page (account deletion, AVIF validation)
      more/                          # more_page
```

### Auth Flow
`main.dart` → Firebase init → `UrbanEasyFlatsApp` → `AuthService.initializeApp()` → check `AuthStorage.isLoggedIn` → resolve role via `VendorService.fetchVendorInfo()` → `AppShell(role, onLogout)`

Auth screens: LandingPage → LoginPage → OtpPage → ProfileSetupPage → AppShell

### Role-Based Navigation
- **Property Manager** tabs: Home, Properties, Contracts, Bills, Account
- **Society Manager** tabs: Home, Residents, Billing, Society, Account
- Both roles share: Dashboard, Support, Communication, Notifications, Settings, More

## Key Dependencies

| Package | Purpose |
|---------|---------|
| http | HTTP client for API calls |
| connectivity_plus | Network status detection |
| url_launcher | External URL schemes (tel, mailto, whatsapp) |
| file_picker | Native file picker for uploads |
| pdf / printing | PDF generation and printing |
| excel | Excel export for society bills |
| razorpay_flutter | Razorpay payment integration |
| firebase_core / firebase_messaging | Push notifications |
| flutter_local_notifications | Local notification display |
| path_provider | Device directory access |
| share_plus | Share files/content |

## Android Build Config

- **Namespace/applicationId:** `com.urbaneasy.manager`
- **Signing:** release keystore at `android/app/upload-keystore.jks`, properties in `android/key.properties`
- **Java/Kotlin target:** 17
- **Gradle:** Kotlin DSL (`build.gradle.kts`)

## Coding Conventions

- snake_case filenames (`custom_button.dart`), PascalCase widgets
- `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` lint rules enabled
- Immutable data models with const constructors
- Feature-based directory structure (one directory per feature module)

## Version

Defined in `pubspec.yaml` — currently `1.0.11+11`.
