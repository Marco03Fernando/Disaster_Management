# DMC Hazard Warning (Flutter)

Mobile app for **citizens** and **duty officers** covering four scenarios: ground hazard reporting, official warnings, shelter/relief coordination, and post-event analytics. UI follows the provided wireframes (deep blue primary, offline banner, severity/scope controls, shelter over-capacity, post-event charts).

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, 3.13+)
- Android Studio / VS Code with Flutter extension (optional)
- For Firebase sync: a Firebase project (see [FIREBASE_SETUP.md](FIREBASE_SETUP.md))

## How to run

```bash
cd hazard_warning_app
flutter pub get
flutter run
```

Pick a device when prompted (Chrome, Windows desktop, Android emulator, or physical phone).

**Use the app**

1. On launch, choose **Citizen** or **Duty officer** (no login).
2. **Citizen:** Home → **Report ground hazard**; view **Reports** tab and alerts after an officer sends a warning.
3. **Officer:** Verify pending reports → **Issue warning** from `GR-2481` → **Shelters** tab for occupancy → **Post-event reports** for analytics.

Switch role anytime via the ⇄ icon on citizen/officer home screens.

## Firebase (optional)

Out of the box the app uses **on-device demo data** (`LocalDataRepository`). After you configure Firebase, it switches to **Cloud Firestore** automatically.

Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md). You will need to:

1. Create a Firebase project in the [Firebase console](https://console.firebase.google.com/).
2. Run `flutterfire configure` in this folder.
3. Enable **Cloud Firestore** (and **Storage** if you later upload photos to the cloud).

## Project structure

```
hazard_warning_app/
├── lib/
│   ├── main.dart                 # Entry: bootstrap services + Provider + router
│   ├── app.dart                  # MaterialApp.router and GoRouter route table
│   ├── firebase_options.dart     # Generated/edited Firebase credentials (placeholder until configured)
│   ├── core/
│   │   ├── theme/app_theme.dart  # Colors, typography aligned with wireframes
│   │   ├── models/models.dart    # Domain types (reports, warnings, shelters, post-event)
│   │   ├── data/seed_data.dart   # Demo seed content (Kelani basin scenario)
│   │   ├── repositories/         # DataRepository + local vs Firebase implementations
│   │   ├── services/app_services.dart  # Firebase bootstrap, connectivity
│   │   ├── state/app_state.dart  # ChangeNotifier shared app state
│   │   └── widgets/common_widgets.dart # Shared UI (headers, pills, buttons)
│   └── features/
│       ├── role_selection/       # Citizen vs officer chooser
│       ├── citizen/              # Reporting + alerts screens
│       └── officer/              # Warnings, shelters, relief, post-event screens
├── assets/images/                # Static assets (optional)
├── SCREENS_BY_USE_CASE.md        # Screen ↔ use case mapping
├── FIREBASE_SETUP.md             # Step-by-step Firebase connection
├── android/, ios/, web/, ...     # Standard Flutter platform folders
└── pubspec.yaml                  # Dependencies (Firebase, go_router, fl_chart, etc.)
```

### Why these layers?

| Area | Role |
|------|------|
| `features/` | One folder per user journey; keeps screens small and discoverable |
| `core/models` | Single source of truth for enums and entities used across citizen/officer flows |
| `core/repositories` | Swaps local demo storage vs Firestore without changing UI code |
| `core/state` | Subscribes to repository streams (reports, warnings, shelters) for reactive UI |
| `go_router` | Deep links for each screen (useful for demos and future auth guards) |

## Dependencies (high level)

- **provider** — app-wide state
- **go_router** — navigation
- **firebase_core / cloud_firestore** — backend when configured
- **connectivity_plus** — offline banner on hazard report
- **image_picker** — hazard photo capture
- **fl_chart** — post-event charts
- **share_plus** — share post-event summary

## Tests

```bash
flutter test
```

## Troubleshooting

- **Firebase not connecting:** Ensure `firebase_options.dart` was replaced by `flutterfire configure` and `DefaultFirebaseOptions.isConfigured` is true (non-placeholder `projectId`).
- **Camera on emulator:** Use a physical device or pick from gallery where supported.
- **Windows/Web:** Demo mode works; some plugins (camera) behave differently on web—use Chrome device toolbar for mobile width.

## What we need from you for production Firebase

When you create the Firebase project, share nothing secret in chat—keep keys in `firebase_options.dart` locally. We only need you to:

1. Create the Firebase project and enable Firestore.
2. Run `flutterfire configure` on your machine (or send us the generated `firebase_options.dart` securely).
3. Optionally set Firestore security rules for your assignment (currently open rules are **not** recommended for production).

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for collection names and seed behaviour.
